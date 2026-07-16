package dev.creapolis.pepinillo

import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.SystemBarStyle
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.ProcessLifecycleOwner
import androidx.activity.viewModels
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import dev.creapolis.pepinillo.core.auth.AuthStore
import dev.creapolis.pepinillo.core.billing.SubscriptionManager
import dev.creapolis.pepinillo.data.sync.SyncEngine
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import javax.inject.Inject
import androidx.compose.animation.AnimatedContentTransitionScope
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.CloudOff
import androidx.compose.material3.MaterialTheme
import androidx.compose.ui.Alignment
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.isImeVisible
import androidx.compose.foundation.layout.systemBars
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import dev.creapolis.pepinillo.data.local.preferences.UserPreferencesRepository
import dev.creapolis.pepinillo.feature.auth.EmailVerificationScreen
import dev.creapolis.pepinillo.feature.auth.ForgotPasswordScreen
import dev.creapolis.pepinillo.feature.auth.LoginScreen
import dev.creapolis.pepinillo.feature.auth.RegisterScreen
import dev.creapolis.pepinillo.feature.onboarding.OnboardingScreen
import dev.creapolis.pepinillo.ui.components.LocalSnackbarController
import dev.creapolis.pepinillo.ui.components.rememberSnackbarController
import kotlinx.coroutines.flow.first
import dev.creapolis.pepinillo.feature.calendar.CalendarScreen
import dev.creapolis.pepinillo.feature.dashboard.AIReportScreen
import dev.creapolis.pepinillo.feature.dashboard.DashboardScreen
import dev.creapolis.pepinillo.feature.focus.FocusScreen
import dev.creapolis.pepinillo.feature.focus.FocusViewModel
import dev.creapolis.pepinillo.feature.more.MoreScreen
import dev.creapolis.pepinillo.feature.more.HelpSupportScreen
import dev.creapolis.pepinillo.feature.more.AboutScreen
import dev.creapolis.pepinillo.feature.more.ExportScreen
import dev.creapolis.pepinillo.feature.paywall.PaywallScreen
import dev.creapolis.pepinillo.feature.profile.ProfileScreen
import dev.creapolis.pepinillo.feature.settings.AppSetupScreen
import dev.creapolis.pepinillo.feature.settings.SettingsScreen
import dev.creapolis.pepinillo.feature.tasks.TaskAnalyticsScreen
import dev.creapolis.pepinillo.feature.tasks.TasksScreen
import dev.creapolis.pepinillo.navigation.TopLevelDestination
import dev.creapolis.pepinillo.ui.theme.PepinilloTheme
import dev.creapolis.pepinillo.ui.theme.ThemeController
import dev.creapolis.pepinillo.ui.theme.ThemeMode
import dev.creapolis.pepinillo.wear.WearDataLayerHelper
import dagger.hilt.android.AndroidEntryPoint

import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

private const val SYNC_DEBOUNCE_MS = 30_000L

/** Nav transition durations (ms). */
private const val DURATION_NAV_MS = 220
private const val DURATION_NAV_DETAIL_MS = 280

/** Translucent scrims so the gesture-nav buttons stay legible over content. */
private const val LIGHT_NAV_SCRIM = 0xE6FFFFFF.toInt()
private const val DARK_NAV_SCRIM = 0x801B1B1B.toInt()

/**
 * Secondary-route (detail/push) transition: a subtle slide-up + fade that reads as
 * "stacking" on top of the current screen. Applied per-composable to override the
 * default tab fade for routes reached via navigate() (analytics, calendar, settings, …).
 */
private val SecondaryEnterTransition: AnimatedContentTransitionScope<*>.() -> androidx.compose.animation.EnterTransition = {
    fadeIn(tween(DURATION_NAV_DETAIL_MS)) +
        slideInVertically(initialOffsetY = { it / 12 }, animationSpec = tween(DURATION_NAV_DETAIL_MS))
}
private val SecondaryPopExitTransition: AnimatedContentTransitionScope<*>.() -> androidx.compose.animation.ExitTransition = {
    fadeOut(tween(DURATION_NAV_DETAIL_MS)) +
        slideOutVertically(targetOffsetY = { it / 12 }, animationSpec = tween(DURATION_NAV_DETAIL_MS))
}

@AndroidEntryPoint
class MainActivity : ComponentActivity() {

    companion object {
        const val EXTRA_NAV_ROUTE = "nav_route"
        const val ROUTE_PAYWALL = "paywall"
    }

    private var isPipMode by mutableStateOf(false)
    private var pendingNavRoute by mutableStateOf<String?>(null)

    private val focusViewModel: FocusViewModel by viewModels()

    @Inject lateinit var syncEngine: SyncEngine
    @Inject lateinit var authStore: AuthStore
    @Inject lateinit var prefsRepository: UserPreferencesRepository
    @Inject lateinit var subscriptionManager: SubscriptionManager
    @Inject lateinit var syncStatusManager: dev.creapolis.pepinillo.data.sync.SyncStatusManager
    @Inject lateinit var authExpiredEvent: dev.creapolis.pepinillo.core.network.AuthExpiredEvent

    private val syncScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    @Volatile
    private var lastSyncTime: Long = 0L

    private val foregroundSyncObserver = LifecycleEventObserver { _, event ->
        if (event == Lifecycle.Event.ON_RESUME) {
            val now = System.currentTimeMillis()
            if (now - lastSyncTime < SYNC_DEBOUNCE_MS) return@LifecycleEventObserver
            if (authStore.getAccessToken() == null) return@LifecycleEventObserver

            lastSyncTime = now
            syncScope.launch {
                Log.d("MainActivity", "Foreground sync triggered")
                syncEngine.syncAll()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        val splashScreen = installSplashScreen()
        // Edge-to-edge with explicit system bar styles so status/nav bar icons keep contrast
        // over transparent bars regardless of content underneath (e.g. the dashboard hero).
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.auto(
                android.graphics.Color.TRANSPARENT,
                android.graphics.Color.TRANSPARENT,
            ),
            navigationBarStyle = SystemBarStyle.auto(
                LIGHT_NAV_SCRIM,
                DARK_NAV_SCRIM,
            ),
        )
        super.onCreate(savedInstanceState)
        pendingNavRoute = intent?.getStringExtra(EXTRA_NAV_ROUTE)
        var isAppReady by mutableStateOf(false)

        // Keep the splash screen on-screen until the app is ready
        splashScreen.setKeepOnScreenCondition { !isAppReady }

        ProcessLifecycleOwner.get().lifecycle.addObserver(foregroundSyncObserver)

        // ... existing syncScope logic ...
        syncScope.launch {
            subscriptionManager.subscriptionState.collect { state ->
                Log.d("MainActivity", "Subscription state changed: ${state.tier}, syncing to Wear OS")
                WearDataLayerHelper.pushUserStatus(this@MainActivity, state.hasLocalPremium)
            }
        }

        setContent {
            // Hold the splash until the persisted theme has been seeded by the Application,
            // so we never draw a frame with the default theme for users who chose another.
            val themeSeeded by ThemeController.isSeeded.collectAsState()
            LaunchedEffect(themeSeeded) {
                if (themeSeeded) {
                    isAppReady = true
                }
            }
            val subscriptionState by subscriptionManager.subscriptionState.collectAsState()
            val themeMode by ThemeController.themeMode.collectAsState()
            val dynamicColor by ThemeController.dynamicColor.collectAsState()
            val selectedTheme by ThemeController.selectedTheme.collectAsState()

            val darkTheme = when (themeMode) {
                ThemeMode.System -> isSystemInDarkTheme()
                ThemeMode.Light -> false
                ThemeMode.Dark -> true
            }

                PepinilloTheme(
                    darkTheme = darkTheme,
                    dynamicColor = dynamicColor,
                    selectedThemeId = selectedTheme,
                    isPro = subscriptionState.hasLocalPremium,
                ) {
                    PepinilloApp(
                        prefsRepository = prefsRepository,
                        isPipMode = isPipMode,
                        syncStatusManager = syncStatusManager,
                        initialNavRoute = pendingNavRoute,
                        onNavRouteConsumed = { pendingNavRoute = null },
                        authStore = authStore,
                        authExpiredEvent = authExpiredEvent,
                    )
                }
        }
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        pendingNavRoute = intent.getStringExtra(EXTRA_NAV_ROUTE)
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: android.content.res.Configuration
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        isPipMode = isInPictureInPictureMode
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        // Enter PiP if a focus session is active
        val uiState = focusViewModel.uiState.value
        if (uiState.isRunning) {
            enterPictureInPictureMode(
                android.app.PictureInPictureParams.Builder().build()
            )
        }
    }

    override fun onDestroy() {
        ProcessLifecycleOwner.get().lifecycle.removeObserver(foregroundSyncObserver)
        syncScope.cancel()
        super.onDestroy()
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun PepinilloApp(
    prefsRepository: UserPreferencesRepository,
    isPipMode: Boolean = false,
    syncStatusManager: dev.creapolis.pepinillo.data.sync.SyncStatusManager,
    initialNavRoute: String? = null,
    onNavRouteConsumed: () -> Unit = {},
    authStore: AuthStore? = null,
    authExpiredEvent: dev.creapolis.pepinillo.core.network.AuthExpiredEvent? = null,
) {
    val navController = rememberNavController()

    LaunchedEffect(initialNavRoute) {
        initialNavRoute?.let { route ->
            navController.navigate(route) { launchSingleTop = true }
            onNavRouteConsumed()
        }
    }

    // Global auth-expired handler: when the session is cleared mid-flight (refresh-401),
    // force-navigate to login instead of leaving the user on a stale screen (#345).
    LaunchedEffect(authExpiredEvent) {
        authExpiredEvent?.events?.collect {
            navController.navigate("login") {
                popUpTo(TopLevelDestination.Focus.route) { inclusive = true }
            }
        }
    }

    // Conditional start destination: if tokens exist but email is NOT verified, cold-start
    // on the verification screen instead of Focus — unverified tokens must not be treated
    // as fully authenticated (#336).
    val startDestination = remember(authStore) {
        val token = authStore?.getAccessToken()
        val verified = authStore?.isEmailVerified() ?: false
        if (token != null && !verified) "email-verification/cold-start" else TopLevelDestination.Focus.route
    }

    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = navBackStackEntry?.destination?.route

    // Hide bottom bar on non-top-level screens (like Profile, Auth) or when in PiP
    val topLevelRoutes = TopLevelDestination.entries.map { it.route }.toSet()
    val isImeVisible = WindowInsets.isImeVisible
    val showBottomBar = currentRoute in topLevelRoutes && !isPipMode && !isImeVisible

    // Global connectivity indicator: a subtle banner when offline.
    val isOnline by syncStatusManager.isOnline.collectAsState()

    val snackbarController = rememberSnackbarController()

    CompositionLocalProvider(LocalSnackbarController provides snackbarController) {
    Scaffold(
        modifier = Modifier.fillMaxSize(),
        contentWindowInsets = WindowInsets.systemBars,
        snackbarHost = { androidx.compose.material3.SnackbarHost(snackbarController.hostState) },
        bottomBar = {
            AnimatedVisibility(
                visible = showBottomBar,
                enter = slideInVertically(initialOffsetY = { it }),
                exit = slideOutVertically(targetOffsetY = { it }),
            ) {
                NavigationBar {
                    TopLevelDestination.entries.forEach { destination ->
                        val isSelected = currentRoute == destination.route
                        NavigationBarItem(
                            selected = isSelected,
                            onClick = {
                                navController.navigate(destination.route) {
                                    popUpTo(navController.graph.findStartDestination().id) {
                                        saveState = true
                                    }
                                    launchSingleTop = true
                                    restoreState = true
                                }
                            },
                            icon = {
                                Icon(
                                    imageVector = if (isSelected) {
                                        destination.selectedIcon
                                    } else {
                                        destination.unselectedIcon
                                    },
                                    contentDescription = stringResource(destination.labelRes),
                                )
                            },
                            label = { Text(stringResource(destination.labelRes)) },
                        )
                    }
                }
            }
        },
    ) { innerPadding ->
        Column(modifier = Modifier.padding(innerPadding)) {
            // Offline banner — surfaces connectivity state that previously only lived in Settings.
            OfflineBanner(isOnline = isOnline)
            NavHost(
            navController = navController,
            startDestination = startDestination,
            modifier = Modifier.fillMaxSize(),
            // Default transition for push/pop: a gentle Material axis-Z slide + fade.
            // This replaces the previous hard cut between every screen.
            enterTransition = { fadeIn(tween(DURATION_NAV_MS)) },
            exitTransition = { fadeOut(tween(DURATION_NAV_MS)) },
            popEnterTransition = { fadeIn(tween(DURATION_NAV_MS)) },
            popExitTransition = { fadeOut(tween(DURATION_NAV_MS)) },
        ) {
            composable(TopLevelDestination.Focus.route) {
                FocusScreen(
                    isPipMode = isPipMode,
                    onMoreClick = {
                        navController.navigate(TopLevelDestination.More.route) {
                            popUpTo(navController.graph.findStartDestination().id) {
                                saveState = true
                            }
                            launchSingleTop = true
                            restoreState = true
                        }
                    },
                    onNavigateToPaywall = {
                        navController.navigate("paywall")
                    },
                )
            }
            composable(TopLevelDestination.Plan.route) {
                TasksScreen(
                    onTaskClick = {},
                    onNavigateToAnalytics = { taskId ->
                        navController.navigate("tasks/$taskId/analytics")
                    },
                    onNavigateToPaywall = {
                        navController.navigate("paywall")
                    },
                    onStartFocusTask = {
                        navController.navigate(TopLevelDestination.Focus.route) {
                            popUpTo(navController.graph.findStartDestination().id) {
                                saveState = true
                            }
                            launchSingleTop = true
                            restoreState = true
                        }
                    },
                )
            }
            composable(
                "tasks/{taskId}/analytics",
                enterTransition = SecondaryEnterTransition,
                popExitTransition = SecondaryPopExitTransition,
            ) {
                TaskAnalyticsScreen(
                    onBack = { navController.popBackStack() },
                )
            }
            composable(TopLevelDestination.Dashboard.route) {
                DashboardScreen(
                    onCalendarClick = { navController.navigate("calendar") },
                    onNavigateToPaywall = { navController.navigate("paywall") },
                    onStartFocusClick = {
                        navController.navigate(TopLevelDestination.Focus.route) {
                            popUpTo(navController.graph.startDestinationId) { saveState = true }
                            launchSingleTop = true
                            restoreState = true
                        }
                    },
                    onNavigateToAIReport = { navController.navigate("ai_report") },
                )
            }
            composable(
                "ai_report",
                enterTransition = SecondaryEnterTransition,
                popExitTransition = SecondaryPopExitTransition,
            ) {
                AIReportScreen(
                    onBack = { navController.popBackStack() },
                )
            }
            composable(
                "calendar",
                enterTransition = SecondaryEnterTransition,
                popExitTransition = SecondaryPopExitTransition,
            ) {
                CalendarScreen(onBack = { navController.popBackStack() })
            }
            composable(
                "profile",
                enterTransition = SecondaryEnterTransition,
                popExitTransition = SecondaryPopExitTransition,
            ) {
                ProfileScreen(
                    onBackClick = { navController.popBackStack() },
                    onSignInClick = { navController.navigate("login") },
                    onSignOutClick = {
                        // Navigate to login after sessionManager.signOut() completes
                        // (ProfileViewModel.logout awaits it before calling this) (#351).
                        navController.navigate("login") {
                            popUpTo(TopLevelDestination.Focus.route) { inclusive = true }
                        }
                    },
                )
            }
            composable(TopLevelDestination.More.route) {
                MoreScreen(
                    onProfileClick = { navController.navigate("profile") },
                    onSignInClick = { navController.navigate("login") },
                    onCreateAccountClick = { navController.navigate("register") },
                    onSettingsClick = { navController.navigate("settings") },
                    onAppSetupClick = { navController.navigate("app_setup") },
                    onExportClick = { navController.navigate("export") },
                    onHelpSupportClick = { navController.navigate("help") },
                    onAboutClick = { navController.navigate("about") },
                    onNavigateToPaywall = { navController.navigate("paywall") },
                )
            }
            composable(
                "help",
                enterTransition = SecondaryEnterTransition,
                popExitTransition = SecondaryPopExitTransition,
            ) {
                HelpSupportScreen(onBack = { navController.popBackStack() })
            }
            composable(
                "about",
                enterTransition = SecondaryEnterTransition,
                popExitTransition = SecondaryPopExitTransition,
            ) {
                AboutScreen(onBack = { navController.popBackStack() })
            }
            composable(
                "export",
                enterTransition = SecondaryEnterTransition,
                popExitTransition = SecondaryPopExitTransition,
            ) {
                ExportScreen(onBack = { navController.popBackStack() })
            }
            composable(
                "settings",
                enterTransition = SecondaryEnterTransition,
                popExitTransition = SecondaryPopExitTransition,
            ) {
                SettingsScreen(
                    onNavigateToAppSetup = { navController.navigate("app_setup") },
                    onNavigateToPaywall = { navController.navigate("paywall") },
                )
            }
            composable(
                "app_setup",
                enterTransition = SecondaryEnterTransition,
                popExitTransition = SecondaryPopExitTransition,
            ) {
                AppSetupScreen(
                    onBack = { navController.popBackStack() },
                )
            }

            // Auth routes
            composable("login") {
                LoginScreen(
                    onNavigateToRegister = { navController.navigate("register") },
                    onNavigateToForgotPassword = { navController.navigate("forgot-password") },
                    onAuthenticated = {
                        navController.navigate(TopLevelDestination.Focus.route) {
                            popUpTo("login") { inclusive = true }
                        }
                    },
                    onEmailVerificationRequired = { email ->
                        // Uri.encode the path segment so '+' and special chars don't
                        // break navigation (#343).
                        navController.navigate("email-verification/${android.net.Uri.encode(email)}")
                    },
                )
            }
            composable("register") {
                RegisterScreen(
                    onNavigateToLogin = { navController.popBackStack() },
                    onAuthenticated = {
                        navController.navigate(TopLevelDestination.Focus.route) {
                            popUpTo("login") { inclusive = true }
                        }
                    },
                    onEmailVerificationRequired = { email ->
                        navController.navigate("email-verification/${android.net.Uri.encode(email)}")
                    },
                )
            }
            composable("forgot-password") {
                ForgotPasswordScreen(
                    onNavigateBack = { navController.popBackStack() },
                    onResetSuccess = {
                        navController.navigate("login") {
                            popUpTo("forgot-password") { inclusive = true }
                        }
                    },
                )
            }
            composable("email-verification/{email}") { backStackEntry ->
                val email = backStackEntry.arguments?.getString("email") ?: ""
                val authViewModel = androidx.hilt.navigation.compose.hiltViewModel<dev.creapolis.pepinillo.feature.auth.AuthViewModel>()
                val uiState by authViewModel.uiState.collectAsState()
                LaunchedEffect(Unit) {
                    authViewModel.restoreEmailVerificationState(email)
                }
                LaunchedEffect(uiState.isAuthenticated) {
                    if (uiState.isAuthenticated) {
                        navController.navigate(TopLevelDestination.Focus.route) {
                            popUpTo("login") { inclusive = true }
                        }
                    }
                }
                EmailVerificationScreen(
                    email = email,
                    onNavigateBack = {
                        authViewModel.dismissEmailVerification()
                        navController.navigate("login") {
                            popUpTo("login") { inclusive = true }
                        }
                    },
                    onVerificationSuccess = {
                        navController.navigate(TopLevelDestination.Focus.route) {
                            popUpTo("login") { inclusive = true }
                        }
                    },
                )
            }
            // Cold-start route for unverified sessions: tokens exist but email isn't
            // verified — force the user to verify before proceeding (#336).
            composable("email-verification/cold-start") {
                val authStore = (authStore)
                val userEmail = authStore?.getUserEmail() ?: ""
                val authViewModel = androidx.hilt.navigation.compose.hiltViewModel<dev.creapolis.pepinillo.feature.auth.AuthViewModel>()
                val uiState by authViewModel.uiState.collectAsState()
                LaunchedEffect(Unit) {
                    authViewModel.restoreEmailVerificationState(userEmail)
                }
                LaunchedEffect(uiState.isAuthenticated) {
                    if (uiState.isAuthenticated) {
                        navController.navigate(TopLevelDestination.Focus.route) {
                            popUpTo("email-verification/cold-start") { inclusive = true }
                        }
                    }
                }
                EmailVerificationScreen(
                    email = userEmail,
                    onNavigateBack = {
                        authViewModel.dismissEmailVerification()
                        navController.navigate("login") {
                            popUpTo("email-verification/cold-start") { inclusive = true }
                        }
                    },
                    onVerificationSuccess = {
                        navController.navigate(TopLevelDestination.Focus.route) {
                            popUpTo("email-verification/cold-start") { inclusive = true }
                        }
                    },
                )
            }

            composable(
                "paywall",
                enterTransition = SecondaryEnterTransition,
                popExitTransition = SecondaryPopExitTransition,
            ) {
                PaywallScreen(
                    onDismiss = { navController.popBackStack() },
                )
            }

            composable("onboarding") {
                val prefsRepo = remember { prefsRepository }
                val prefs by prefsRepo.preferences.collectAsState(initial = null)
                val onboardingScope = rememberCoroutineScope()

                OnboardingScreen(
                    initialPage = prefs?.onboardingPage ?: 0,
                    onPageChanged = { page ->
                        onboardingScope.launch {
                            prefsRepo.updateOnboardingPage(page)
                        }
                    },
                    onComplete = {
                        onboardingScope.launch {
                            prefsRepo.completeOnboarding()
                        }
                        navController.navigate(TopLevelDestination.Focus.route) {
                            popUpTo("onboarding") { inclusive = true }
                        }
                    },
                )
            }
        }
        } // Column
    }
    } // CompositionLocalProvider(LocalSnackbarController)
}

/**
 * Subtle offline banner shown at the top of the app content when there's no connection.
 * Surfaces connectivity state that previously only lived in Settings (SyncStatusManager.isOnline).
 */
@Composable
private fun OfflineBanner(isOnline: Boolean) {
    androidx.compose.animation.AnimatedVisibility(
        visible = !isOnline,
        enter = slideInVertically { -it } + fadeIn(),
        exit = slideOutVertically { -it } + fadeOut(),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(MaterialTheme.colorScheme.errorContainer)
                .padding(horizontal = 16.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center,
        ) {
            Icon(
                imageVector = Icons.Rounded.CloudOff,
                contentDescription = null,
                modifier = Modifier.size(16.dp),
                tint = MaterialTheme.colorScheme.onErrorContainer,
            )
            Spacer(modifier = Modifier.width(8.dp))
            Text(
                text = stringResource(R.string.banner_offline),
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onErrorContainer,
            )
        }
    }
}
