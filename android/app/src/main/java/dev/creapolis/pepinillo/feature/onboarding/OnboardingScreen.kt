package dev.creapolis.pepinillo.feature.onboarding

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Analytics
import androidx.compose.material.icons.rounded.CloudSync
import androidx.compose.material.icons.rounded.Rocket
import androidx.compose.material.icons.rounded.TaskAlt
import androidx.compose.material.icons.rounded.Timer
import androidx.compose.material.icons.rounded.Widgets
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import dev.creapolis.pepinillo.R
import kotlinx.coroutines.launch

private data class OnboardingPage(
    val icon: ImageVector,
    val titleRes: Int,
    val descRes: Int,
)

@Composable
private fun onboardingPages() = listOf(
    OnboardingPage(
        icon = Icons.Rounded.Rocket,
        titleRes = R.string.onboarding_welcome_title,
        descRes = R.string.onboarding_welcome_desc,
    ),
    OnboardingPage(
        icon = Icons.Rounded.Timer,
        titleRes = R.string.onboarding_modes_title,
        descRes = R.string.onboarding_modes_desc,
    ),
    OnboardingPage(
        icon = Icons.Rounded.CloudSync,
        titleRes = R.string.onboarding_everywhere_title,
        descRes = R.string.onboarding_everywhere_desc,
    ),
    OnboardingPage(
        icon = Icons.Rounded.TaskAlt,
        titleRes = R.string.onboarding_tasks_title,
        descRes = R.string.onboarding_tasks_desc,
    ),
    OnboardingPage(
        icon = Icons.Rounded.Widgets,
        titleRes = R.string.onboarding_widgets_title,
        descRes = R.string.onboarding_widgets_desc,
    ),
    OnboardingPage(
        icon = Icons.Rounded.Analytics,
        titleRes = R.string.onboarding_ready_title,
        descRes = R.string.onboarding_ready_desc,
    ),
)

/**
 * Returns the full-bleed background color for each onboarding page index.
 * Colors are drawn from Material 3 container tokens so they adapt to the
 * active color scheme (Dynamic Color on Android 12+, static otherwise).
 */
@Composable
private fun pageBackground(index: Int): Color = when (index) {
    0 -> MaterialTheme.colorScheme.primaryContainer
    1 -> MaterialTheme.colorScheme.tertiaryContainer
    2 -> MaterialTheme.colorScheme.secondaryContainer
    3 -> MaterialTheme.colorScheme.primaryContainer
    4 -> MaterialTheme.colorScheme.tertiaryContainer
    else -> MaterialTheme.colorScheme.secondaryContainer
}

/**
 * Returns the content color (text / icon tint) that has sufficient contrast
 * on the [pageBackground] for the given page index.
 */
@Composable
private fun pageContentColor(index: Int): Color = when (index) {
    0 -> MaterialTheme.colorScheme.onPrimaryContainer
    1 -> MaterialTheme.colorScheme.onTertiaryContainer
    2 -> MaterialTheme.colorScheme.onSecondaryContainer
    3 -> MaterialTheme.colorScheme.onPrimaryContainer
    4 -> MaterialTheme.colorScheme.onTertiaryContainer
    else -> MaterialTheme.colorScheme.onSecondaryContainer
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun OnboardingScreen(
    onComplete: () -> Unit,
    initialPage: Int = 0,
    onPageChanged: (Int) -> Unit = {},
) {
    val pages = onboardingPages()
    val pagerState = rememberPagerState(
        initialPage = initialPage.coerceIn(0, pages.size - 1),
        pageCount = { pages.size },
    )
    val scope = rememberCoroutineScope()
    val isLastPage = pagerState.currentPage == pages.size - 1

    // Animate the full-bleed background across page transitions
    val targetBg = pageBackground(pagerState.currentPage)
    val animatedBg by animateColorAsState(
        targetValue = targetBg,
        animationSpec = tween(durationMillis = 350),
        label = "onboardingBg",
    )
    val targetContent = pageContentColor(pagerState.currentPage)
    val animatedContent by animateColorAsState(
        targetValue = targetContent,
        animationSpec = tween(durationMillis = 350),
        label = "onboardingContent",
    )

    // Persist page changes
    LaunchedEffect(pagerState) {
        snapshotFlow { pagerState.currentPage }.collect { page ->
            onPageChanged(page)
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(animatedBg),
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(24.dp),
        ) {
            // Skip button — dark pill backing for WCAG contrast on any background color
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.End,
            ) {
                if (!isLastPage) {
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(20.dp))
                            .background(Color.Black.copy(alpha = 0.18f))
                            .padding(horizontal = 4.dp),
                    ) {
                        TextButton(onClick = onComplete) {
                            Text(
                                text = stringResource(R.string.btn_skip),
                                color = animatedContent,
                            )
                        }
                    }
                }
            }

            // Pager
            HorizontalPager(
                state = pagerState,
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f),
            ) { page ->
                val item = pages[page]
                Column(
                    modifier = Modifier.fillMaxSize(),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center,
                ) {
                    // Icon circle — tinted to match each page's content color
                    Box(
                        modifier = Modifier
                            .size(120.dp)
                            .clip(CircleShape)
                            .background(animatedContent.copy(alpha = 0.15f)),
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(
                            imageVector = item.icon,
                            contentDescription = null,
                            modifier = Modifier.size(56.dp),
                            tint = animatedContent,
                        )
                    }
                    Spacer(modifier = Modifier.size(40.dp))
                    // Title — no maxLines so it wraps at XXXL Dynamic Font
                    Text(
                        text = stringResource(item.titleRes),
                        style = MaterialTheme.typography.headlineSmall,
                        fontWeight = FontWeight.Bold,
                        textAlign = TextAlign.Center,
                        color = animatedContent,
                    )
                    Spacer(modifier = Modifier.size(16.dp))
                    Text(
                        text = stringResource(item.descRes),
                        style = MaterialTheme.typography.bodyLarge,
                        color = animatedContent.copy(alpha = 0.75f),
                        textAlign = TextAlign.Center,
                        modifier = Modifier.padding(horizontal = 16.dp),
                    )
                }
            }

            // Page indicators
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.Center,
            ) {
                repeat(pages.size) { index ->
                    val dotColor = if (index == pagerState.currentPage) {
                        animatedContent
                    } else {
                        animatedContent.copy(alpha = 0.35f)
                    }
                    Box(
                        modifier = Modifier
                            .padding(horizontal = 4.dp)
                            .size(if (index == pagerState.currentPage) 10.dp else 8.dp)
                            .clip(CircleShape)
                            .background(dotColor),
                    )
                }
            }

            Spacer(modifier = Modifier.size(32.dp))

            // CTA button — heightIn so label can grow at large font scale
            Button(
                onClick = {
                    if (isLastPage) {
                        onComplete()
                    } else {
                        scope.launch { pagerState.animateScrollToPage(pagerState.currentPage + 1) }
                    }
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(min = 56.dp),
                shape = RoundedCornerShape(12.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = animatedContent,
                    contentColor = animatedBg,
                ),
            ) {
                Text(
                    text = if (isLastPage) stringResource(R.string.btn_get_started) else stringResource(R.string.btn_next),
                    style = MaterialTheme.typography.titleMedium,
                )
            }

            Spacer(modifier = Modifier.size(16.dp))
        }
    }
}
