package dev.creapolis.pepinillo.feature.paywall

import android.app.Activity
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AccessTime
import androidx.compose.material.icons.rounded.Analytics
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.CloudSync
import androidx.compose.material.icons.rounded.LocalFireDepartment
import androidx.compose.material.icons.rounded.MusicNote
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material.icons.rounded.Sync
import androidx.compose.material.icons.rounded.TaskAlt
import androidx.compose.material.icons.rounded.Watch
import androidx.compose.material.icons.rounded.Widgets
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Surface
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.RadioButton
import androidx.compose.material3.RadioButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import dev.creapolis.pepinillo.core.billing.PepinilloProducts

@Composable
fun PaywallScreen(
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier,
    viewModel: PaywallViewModel = hiltViewModel(),
) {
    val uiState by viewModel.uiState.collectAsState()
    val activity = LocalContext.current as? Activity

    if (uiState.isPro) {
        // Auto-dismiss if user became pro
        onDismiss()
        return
    }

    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 24.dp),
    ) {
        Spacer(modifier = Modifier.height(16.dp))

        // ── CLOSE BUTTON ──
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.End,
        ) {
            IconButton(onClick = onDismiss) {
                Icon(
                    Icons.Rounded.Close,
                    contentDescription = "Close",
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }

        // ── HEADER ──
        Column(
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Box(
                modifier = Modifier
                    .size(64.dp)
                    .clip(CircleShape)
                    .background(MaterialTheme.colorScheme.primaryContainer),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    Icons.Rounded.Star,
                    contentDescription = null,
                    modifier = Modifier.size(32.dp),
                    tint = MaterialTheme.colorScheme.primary,
                )
            }
            Spacer(modifier = Modifier.height(16.dp))
            Text(
                text = "Get Pepinillo+",
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurface,
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = "Unlock the full Pepinillo experience",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )
        }

        Spacer(modifier = Modifier.height(28.dp))

        // ── TIER CARDS ──
        TierCard(
            tierName = "Pepinillo+",
            badge = "One-time",
            badgeGreen = true,
            features = listOf(
                Triple(Icons.Rounded.AccessTime, "All focus modes", "Flowtime, Time Blocks & more"),
                Triple(Icons.Rounded.TaskAlt, "Unlimited tasks", "Subtasks, recurrence & scheduling"),
                Triple(Icons.Rounded.MusicNote, "Premium soundscapes", "Binaural beats, lo-fi & more"),
                Triple(Icons.Rounded.Analytics, "Full analytics", "Complete history & reviews"),
                Triple(Icons.Rounded.Widgets, "All widgets", "Home screen & lock screen"),
                Triple(Icons.Rounded.Watch, "Wear OS", "Full smartwatch app & complications"),
            ),
        )

        Spacer(modifier = Modifier.height(12.dp))

        TierCard(
            tierName = "Everywhere / AI+",
            badge = "Subscription",
            badgeGreen = false,
            features = listOf(
                Triple(Icons.Rounded.Star, "Everything in Pepinillo+", "All local features included"),
                Triple(Icons.Rounded.CloudSync, "Cloud sync", "Backup & sync across devices"),
                Triple(Icons.Rounded.AutoAwesome, "AI Focus Reports", "Personalized insights"),
                Triple(Icons.Rounded.Sync, "Multi-device", "Available anywhere, anytime"),
            ),
            comingSoonIndices = setOf(2, 3),
        )

        Spacer(modifier = Modifier.height(28.dp))

        // ── PRODUCT CARDS ──
        if (uiState.products.isNotEmpty()) {
            uiState.products.forEach { product ->
                val isSelected = product.productId == uiState.selectedProductId
                val isAnnual = product.productId == PepinilloProducts.EVERYWHERE_ANNUAL
                ProductCard(
                    name = when {
                        product.productId == PepinilloProducts.EVERYWHERE_MONTHLY -> "Monthly"
                        product.productId == PepinilloProducts.EVERYWHERE_ANNUAL -> "Annual"
                        product.productId == PepinilloProducts.EVERYWHERE_LIFETIME -> "Lifetime"
                        product.productId == PepinilloProducts.PEPINILLO_PLUS -> "Pepinillo+"
                        else -> product.title
                    },
                    price = product.formattedPrice,
                    period = when (product.billingPeriod) {
                        "P1M" -> "/month"
                        "P1Y" -> "/year"
                        null -> " once"
                        else -> ""
                    },
                    isSelected = isSelected,
                    isFeatured = isAnnual,
                    onClick = { viewModel.selectProduct(product.productId) },
                )
                Spacer(modifier = Modifier.height(8.dp))
            }
        } else {
            // Loading products
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(120.dp),
                contentAlignment = Alignment.Center,
            ) {
                CircularProgressIndicator(
                    modifier = Modifier.size(24.dp),
                    strokeWidth = 2.dp,
                    color = MaterialTheme.colorScheme.primary,
                )
            }
        }

        Spacer(modifier = Modifier.height(20.dp))

        // ── PURCHASE BUTTON ──
        Button(
            onClick = { activity?.let { viewModel.purchase(it) } },
            modifier = Modifier
                .fillMaxWidth()
                .height(56.dp),
            shape = RoundedCornerShape(28.dp),
            enabled = uiState.selectedProductId != null && !uiState.isPurchasing,
            colors = ButtonDefaults.buttonColors(
                containerColor = MaterialTheme.colorScheme.primary,
            ),
        ) {
            if (uiState.isPurchasing) {
                CircularProgressIndicator(
                    modifier = Modifier.size(20.dp),
                    strokeWidth = 2.dp,
                    color = MaterialTheme.colorScheme.onPrimary,
                )
            } else {
                val buttonLabel = when (uiState.selectedProductId) {
                    PepinilloProducts.PEPINILLO_PLUS -> "Get Pepinillo+"
                    PepinilloProducts.EVERYWHERE_MONTHLY, PepinilloProducts.EVERYWHERE_ANNUAL -> "Start Subscription"
                    PepinilloProducts.EVERYWHERE_LIFETIME -> "Get Lifetime Access"
                    else -> "Continue"
                }
                Text(
                    text = buttonLabel,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                )
            }
        }

        // ── ERROR ──
        uiState.error?.let { error ->
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = error,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.error,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth(),
            )
        }

        Spacer(modifier = Modifier.height(12.dp))

        // ── RESTORE ──
        TextButton(
            onClick = { viewModel.restorePurchases() },
            modifier = Modifier.align(Alignment.CenterHorizontally),
        ) {
            Text(
                text = "Restore Purchases",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }

        Spacer(modifier = Modifier.height(8.dp))

        // ── LEGAL ──
        Text(
            text = "Subscriptions auto-renew unless canceled at least 24 hours before the end of the current period. Manage subscriptions in Google Play settings.",
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f),
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth(),
        )

        Spacer(modifier = Modifier.height(24.dp))
    }
}

@Composable
private fun TierCard(
    tierName: String,
    badge: String,
    badgeGreen: Boolean,
    features: List<Triple<ImageVector, String, String>>,
    comingSoonIndices: Set<Int> = emptySet(),
) {
    val accentColor = if (badgeGreen) MaterialTheme.colorScheme.tertiary else MaterialTheme.colorScheme.primary
    val badgeBg = if (badgeGreen) MaterialTheme.colorScheme.tertiaryContainer else MaterialTheme.colorScheme.primaryContainer
    val badgeFg = if (badgeGreen) MaterialTheme.colorScheme.onTertiaryContainer else MaterialTheme.colorScheme.onPrimaryContainer
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(20.dp))
            .border(1.dp, accentColor.copy(alpha = 0.3f), RoundedCornerShape(20.dp))
            .background(accentColor.copy(alpha = 0.04f))
            .padding(16.dp),
    ) {
        Column {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Icon(
                    imageVector = Icons.Rounded.Star,
                    contentDescription = null,
                    modifier = Modifier.size(18.dp),
                    tint = accentColor,
                )
                Spacer(modifier = Modifier.width(6.dp))
                Text(
                    text = tierName,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = accentColor,
                )
                Spacer(modifier = Modifier.weight(1f))
                Text(
                    text = badge,
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.Bold,
                    color = badgeFg,
                    modifier = Modifier
                        .clip(RoundedCornerShape(8.dp))
                        .background(badgeBg)
                        .padding(horizontal = 8.dp, vertical = 3.dp),
                )
            }
            Spacer(modifier = Modifier.height(12.dp))
            HorizontalDivider(color = accentColor.copy(alpha = 0.15f))
            Spacer(modifier = Modifier.height(12.dp))
            features.forEachIndexed { index, (icon, title, subtitle) ->
                TierFeatureRow(
                    icon = icon,
                    title = title,
                    subtitle = subtitle,
                    comingSoon = index in comingSoonIndices,
                    accentColor = accentColor,
                )
                if (index < features.lastIndex) Spacer(modifier = Modifier.height(8.dp))
            }
        }
    }
}

@Composable
private fun TierFeatureRow(
    icon: ImageVector,
    title: String,
    subtitle: String,
    comingSoon: Boolean,
    accentColor: androidx.compose.ui.graphics.Color,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = Modifier
                .size(32.dp)
                .clip(RoundedCornerShape(8.dp))
                .background(accentColor.copy(alpha = 0.12f)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                modifier = Modifier.size(16.dp),
                tint = accentColor,
            )
        }
        Spacer(modifier = Modifier.width(10.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = title,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Medium,
                color = MaterialTheme.colorScheme.onSurface,
            )
            Text(
                text = subtitle,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        if (comingSoon) {
            Spacer(modifier = Modifier.width(8.dp))
            Text(
                text = "Soon",
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier
                    .clip(RoundedCornerShape(6.dp))
                    .background(MaterialTheme.colorScheme.surfaceVariant)
                    .padding(horizontal = 6.dp, vertical = 2.dp),
            )
        }
    }
}

@Composable
private fun ProFeatureRow(
    icon: ImageVector,
    title: String,
    subtitle: String,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = Modifier
                .size(40.dp)
                .clip(RoundedCornerShape(12.dp))
                .background(MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.5f)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                modifier = Modifier.size(20.dp),
                tint = MaterialTheme.colorScheme.primary,
            )
        }
        Spacer(modifier = Modifier.width(12.dp))
        Column {
            Text(
                text = title,
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.Medium,
                color = MaterialTheme.colorScheme.onSurface,
            )
            Text(
                text = subtitle,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun ProductCard(
    name: String,
    price: String,
    period: String,
    isSelected: Boolean,
    isFeatured: Boolean,
    onClick: () -> Unit,
) {
    val borderColor by animateColorAsState(
        targetValue = if (isSelected) MaterialTheme.colorScheme.primary
        else MaterialTheme.colorScheme.outlineVariant,
        animationSpec = spring(),
        label = "productBorder",
    )

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .border(
                width = if (isSelected) 2.dp else 1.dp,
                color = borderColor,
                shape = RoundedCornerShape(16.dp),
            )
            .clickable(onClick = onClick)
            .padding(16.dp),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth(),
        ) {
            RadioButton(
                selected = isSelected,
                onClick = onClick,
                colors = RadioButtonDefaults.colors(
                    selectedColor = MaterialTheme.colorScheme.primary,
                ),
            )
            Spacer(modifier = Modifier.width(8.dp))
            Column(modifier = Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = name,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                    if (isFeatured) {
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = "BEST VALUE",
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onPrimary,
                            modifier = Modifier
                                .clip(RoundedCornerShape(8.dp))
                                .background(MaterialTheme.colorScheme.primary)
                                .padding(horizontal = 8.dp, vertical = 2.dp),
                        )
                    }
                }
            }
            Text(
                text = "$price$period",
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.Medium,
                color = MaterialTheme.colorScheme.onSurface,
            )
        }
    }
}
