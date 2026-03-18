package dev.creapolis.pepinillo

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import dev.creapolis.pepinillo.data.local.preferences.UserPreferencesRepository
import dev.creapolis.pepinillo.feature.auth.LoginScreen
import dev.creapolis.pepinillo.feature.auth.RegisterScreen
import dev.creapolis.pepinillo.feature.onboarding.OnboardingScreen
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import dev.creapolis.pepinillo.feature.dashboard.DashboardScreen
import dev.creapolis.pepinillo.feature.focus.FocusScreen
import dev.creapolis.pepinillo.feature.profile.ProfileScreen
import dev.creapolis.pepinillo.feature.settings.SettingsScreen
import dev.creapolis.pepinillo.feature.tasks.TasksScreen
import dev.creapolis.pepinillo.feature.tasks.detail.TaskDetailScreen
import dev.creapolis.pepinillo.navigation.TopLevelDestination
import dev.creapolis.pepinillo.ui.theme.PepinilloTheme
import dev.creapolis.pepinillo.ui.theme.ThemeController
import dev.creapolis.pepinillo.ui.theme.ThemeMode
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class MainActivity : ComponentActivity() {

    private val notificationPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { /* granted or not, we continue */ }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        requestNotificationPermissionIfNeeded()
        setContent {
            val themeMode by ThemeController.themeMode.collectAsState()
            val dynamicColor by ThemeController.dynamicColor.collectAsState()

            val darkTheme = when (themeMode) {
                ThemeMode.System -> isSystemInDarkTheme()
                ThemeMode.Light -> false
                ThemeMode.Dark -> true
            }

            PepinilloTheme(
                darkTheme = darkTheme,
                dynamicColor = dynamicColor,
            ) {
                PepinilloApp()
            }
        }
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
fun PepinilloApp() {
    val navController = rememberNavController()
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = navBackStackEntry?.destination?.route

    // Hide bottom bar on non-top-level screens (like Profile, Auth)
    val topLevelRoutes = TopLevelDestination.entries.map { it.route }.toSet()
    val authRoutes = setOf("login", "register")
    val showBottomBar = currentRoute in topLevelRoutes

    Scaffold(
        modifier = Modifier.fillMaxSize(),
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
                                    contentDescription = destination.label,
                                )
                            },
                            label = { Text(destination.label) },
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
                    onProfileClick = {
                        navController.navigate("profile")
                    },
                )
            }
            composable(TopLevelDestination.Tasks.route) {
                TasksScreen(
                    onTaskClick = { taskId ->
                        navController.navigate("tasks/$taskId")
                    },
                )
            }
            composable("tasks/{taskId}") {
                TaskDetailScreen(
                    onBack = { navController.popBackStack() },
                    onStartFocus = { taskId ->
                        // Navigate to focus screen (task linking can be handled via shared state)
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
            composable(TopLevelDestination.Dashboard.route) {
                DashboardScreen()
            }
            composable("profile") {
                ProfileScreen(
                    onBackClick = { navController.popBackStack() },
                    onSignInClick = { navController.navigate("login") },
                    onSignOutClick = { /* handled internally */ },
                )
            }
            composable(TopLevelDestination.Settings.route) {
                SettingsScreen()
            }

            // Auth routes
            composable("login") {
                LoginScreen(
                    onNavigateToRegister = { navController.navigate("register") },
                    onAuthenticated = {
                        navController.navigate(TopLevelDestination.Focus.route) {
                            popUpTo("login") { inclusive = true }
                        }
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
                )
            }

            composable("onboarding") {
                OnboardingScreen(
                    onComplete = {
                        navController.navigate(TopLevelDestination.Focus.route) {
                            popUpTo("onboarding") { inclusive = true }
                        }
                    },
                )
            }
        }
    }
}
