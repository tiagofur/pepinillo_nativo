package dev.creapolis.pepinillo

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
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
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.systemBars
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
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
import dev.creapolis.pepinillo.feature.tasks.detail.TaskDetailScreen
import dev.creapolis.pepinillo.navigation.TopLevelDestination
import dev.creapolis.pepinillo.ui.theme.PepinilloTheme
import dev.creapolis.pepinillo.ui.theme.ThemeController
import dev.creapolis.pepinillo.ui.theme.ThemeMode
import dev.creapolis.pepinillo.wear.WearDataLayerHelper
import dagger.hilt.android.AndroidEntryPoint

import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

private const val SYNC_DEBOUNCE_MS = 30_000L

@AndroidEntryPoint
class MainActivity : ComponentActivity() {

    private var isPipMode by mutableStateOf(false)

    private val focusViewModel: FocusViewModel by viewModels()

    @Inject lateinit var syncEngine: SyncEngine
    @Inject lateinit var authStore: AuthStore
    @Inject lateinit var prefsRepository: UserPreferencesRepository
    @Inject lateinit var subscriptionManager: SubscriptionManager

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

    private val notificationPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { /* granted or not, we continue */ }

    override fun onCreate(savedInstanceState: Bundle?) {
        val splashScreen = installSplashScreen()
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
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
            // Notify system that we are ready to draw
            LaunchedEffect(Unit) {
                isAppReady = true
                requestNotificationPermissionIfNeeded()
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
                        isPipMode = isPipMode
                    )
                }
        }
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

    private fun requestNotificationPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(
                    this, Manifest.permission.POST_NOTIFICATIONS,
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
            }
        }
    }
}

@Composable
fun PepinilloApp(
    prefsRepository: UserPreferencesRepository,
    isPipMode: Boolean = false
) {
    val navController = rememberNavController()
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = navBackStackEntry?.destination?.route

    // Hide bottom bar on non-top-level screens (like Profile, Auth) or when in PiP
    val topLevelRoutes = TopLevelDestination.entries.map { it.route }.toSet()
    val showBottomBar = currentRoute in topLevelRoutes && !isPipMode

    Scaffold(
        modifier = Modifier.fillMaxSize(),
        contentWindowInsets = WindowInsets.systemBars,
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
        NavHost(
            navController = navController,
            startDestination = TopLevelDestination.Focus.route,
            modifier = Modifier.padding(innerPadding),
            enterTransition = { fadeIn(tween(250)) },
            exitTransition = { fadeOut(tween(250)) },
            popEnterTransition = { fadeIn(tween(250)) },
            popExitTransition = { fadeOut(tween(250)) },
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
                    onTaskClick = { taskId ->
                        navController.navigate("tasks/$taskId")
                    },
                    onNavigateToPaywall = {
                        navController.navigate("paywall")
                    },
                )
            }
            composable("tasks/{taskId}") {
                TaskDetailScreen(
                    onBack = { navController.popBackStack() },
                )
            }
            composable("tasks/{taskId}/analytics") {
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
            composable("ai_report") {
                AIReportScreen(
                    onBack = { navController.popBackStack() },
                )
            }
            composable("calendar") {
                CalendarScreen(onBack = { navController.popBackStack() })
            }
            composable("profile") {
                ProfileScreen(
                    onBackClick = { navController.popBackStack() },
                    onSignInClick = { navController.navigate("login") },
                    onSignOutClick = { /* handled internally */ },
                )
            }
            composable(TopLevelDestination.More.route) {
                MoreScreen(
                    onProfileClick = { navController.navigate("profile") },
                    onSignInClick = { navController.navigate("login") },
                    onCreateAccountClick = { navController.navigate("register") },
                    onSettingsClick = { navController.navigate("settings") },
                    onExportClick = { navController.navigate("export") },
                    onHelpSupportClick = { navController.navigate("help") },
                    onAboutClick = { navController.navigate("about") },
                    onNavigateToPaywall = { navController.navigate("paywall") },
                )
            }
            composable("help") {
                HelpSupportScreen(onBack = { navController.popBackStack() })
            }
            composable("about") {
                AboutScreen(onBack = { navController.popBackStack() })
            }
            composable("export") {
                ExportScreen(onBack = { navController.popBackStack() })
            }
            composable("settings") {
                SettingsScreen(
                    onNavigateToAppSetup = { navController.navigate("app_setup") },
                    onNavigateToPaywall = { navController.navigate("paywall") },
                )
            }
            composable("app_setup") {
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
                        navController.navigate("email-verification/$email")
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
                        navController.navigate("email-verification/$email")
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

            composable("paywall") {
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
    }
}
