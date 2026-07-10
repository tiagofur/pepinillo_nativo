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
import androidx.compose.foundation.layout.heightIn
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
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import dev.creapolis.pepinillo.R
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
                    contentDescription = stringResource(R.string.cd_close),
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
                text = stringResource(R.string.paywall_title),
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurface,
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = stringResource(R.string.paywall_subtitle),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )
        }

        Spacer(modifier = Modifier.height(28.dp))

        // ── TIER CARDS ──
        TierCard(
            tierName = "Pepinillo+",
            badge = stringResource(R.string.paywall_one_time),
            badgeGreen = true,
            features = listOf(
                Triple(Icons.Rounded.Star, stringResource(R.string.feature_local_premium), stringResource(R.string.feature_local_premium_desc)),
                Triple(Icons.Rounded.AccessTime, stringResource(R.string.feature_adv_timer), stringResource(R.string.feature_adv_timer_desc)),
                Triple(Icons.Rounded.TaskAlt, stringResource(R.string.feature_unlimited_tasks), stringResource(R.string.feature_unlimited_tasks_desc)),
                Triple(Icons.Rounded.Watch, stringResource(R.string.feature_wearos), stringResource(R.string.feature_wearos_desc)),
                Triple(Icons.Rounded.Analytics, stringResource(R.string.feature_adv_stats), stringResource(R.string.feature_adv_stats_desc)),
            ),
        )

        Spacer(modifier = Modifier.height(12.dp))

        TierCard(
            tierName = "Everywhere / AI+",
            badge = stringResource(R.string.paywall_subscription),
            badgeGreen = false,
            features = listOf(
                Triple(Icons.Rounded.CloudSync, stringResource(R.string.feature_cloud_sync), stringResource(R.string.feature_cloud_sync_desc)),
                Triple(Icons.Rounded.AutoAwesome, stringResource(R.string.feature_ai_reports), stringResource(R.string.feature_ai_reports_desc)),
                Triple(Icons.Rounded.Sync, stringResource(R.string.feature_vps_backup), stringResource(R.string.feature_vps_backup_desc)),
                Triple(Icons.Rounded.Star, stringResource(R.string.feature_pro_included), stringResource(R.string.feature_pro_included_desc)),
            ),
            comingSoonIndices = emptySet(), // AI Reports is now functional!
        )

        Spacer(modifier = Modifier.height(28.dp))

        // ── PRODUCT CARDS ──
        if (uiState.products.isNotEmpty()) {
            uiState.products.forEach { product ->
                val isSelected = product.productId == uiState.selectedProductId
                val isAnnual = product.productId == PepinilloProducts.EVERYWHERE_ANNUAL
                ProductCard(
                    name = when {
                        product.productId == PepinilloProducts.EVERYWHERE_MONTHLY -> stringResource(R.string.paywall_monthly)
                        product.productId == PepinilloProducts.EVERYWHERE_ANNUAL -> stringResource(R.string.paywall_annual)
                        product.productId == PepinilloProducts.PEPINILLO_PLUS -> "Pepinillo+"
                        else -> product.title
                    },
                    price = product.formattedPrice,
                    period = when (product.billingPeriod) {
                        "P1M" -> stringResource(R.string.paywall_unit_month)
                        "P1Y" -> stringResource(R.string.paywall_unit_year)
                        null -> stringResource(R.string.paywall_unit_once)
                        else -> ""
                    },
                    isSelected = isSelected,
                    isFeatured = isAnnual,
                    onClick = { viewModel.selectProduct(product.productId) },
                    // Per-month equivalent for annual — boosts conversion.
                    subtitle = if (isAnnual && product.priceMicros > 0) {
                        val monthlyMicros = product.priceMicros / 12
                        val currency = product.formattedPrice.takeWhile { !it.isDigit() }.trim()
                        val monthlyStr = currency + "%.2f".format(monthlyMicros / 1_000_000.0)
                        stringResource(R.string.paywall_per_month, monthlyStr)
                    } else null,
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

        Spacer(modifier = Modifier.height(8.dp))

        // Risk-reversal line — aids conversion by reducing purchase anxiety.
        Text(
            text = stringResource(R.string.paywall_risk_reversal),
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth(),
        )

        Spacer(modifier = Modifier.height(16.dp))

        // ── PURCHASE BUTTON ──
        // heightIn instead of fixed height so the label can wrap at large font scales
        Button(
            onClick = { activity?.let { viewModel.purchase(it) } },
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = 56.dp),
            shape = RoundedCornerShape(12.dp),
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
                    PepinilloProducts.PEPINILLO_PLUS -> stringResource(R.string.paywall_btn_get_plus)
                    PepinilloProducts.EVERYWHERE_MONTHLY, PepinilloProducts.EVERYWHERE_ANNUAL -> stringResource(R.string.paywall_btn_start_sub)
                    else -> stringResource(R.string.paywall_btn_continue)
                }
                Text(
                    text = buttonLabel,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                )
            }
        }

        // ── ERROR ──
        uiState.errorRes?.let { errorRes ->
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = stringResource(errorRes),
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
                text = stringResource(R.string.paywall_btn_restore),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }

        Spacer(modifier = Modifier.height(8.dp))

        // ── LEGAL ──
        Text(
            text = stringResource(R.string.paywall_legal),
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
                // Allow multi-line at XXXL font scale instead of silent clipping
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                text = subtitle,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                overflow = TextOverflow.Ellipsis,
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
                    .clip(RoundedCornerShape(8.dp))
                    .background(MaterialTheme.colorScheme.surfaceVariant)
                    .padding(horizontal = 6.dp, vertical = 2.dp),
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
    subtitle: String? = null,
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
            .clip(RoundedCornerShape(12.dp))
            .border(
                width = if (isSelected) 2.dp else 1.dp,
                color = borderColor,
                shape = RoundedCornerShape(12.dp),
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
                            text = stringResource(R.string.paywall_best_value),
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onPrimary,
                            modifier = Modifier
                                .clip(RoundedCornerShape(8.dp))
                                .background(MaterialTheme.colorScheme.primary)
                                .padding(horizontal = 8.dp, vertical = 2.dp),
                        )
                    }
                    if (subtitle != null) {
                        Text(
                            text = subtitle,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.padding(top = 2.dp),
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
