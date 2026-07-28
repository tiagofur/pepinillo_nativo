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
import android.content.Intent
import android.net.Uri
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
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
import dev.creapolis.pepinillo.ui.theme.PepinilloShapeTokens

@Composable
fun PaywallScreen(
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier,
    viewModel: PaywallViewModel = hiltViewModel(),
) {
    val uiState by viewModel.uiState.collectAsState()
    val context = LocalContext.current
    val activity = context as? Activity

    LaunchedEffect(uiState.shouldAutoDismiss) {
        if (uiState.shouldAutoDismiss) {
            onDismiss()
        }
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
            tierName = stringResource(R.string.tier_name_pepinillo_plus),
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
                        product.productId == PepinilloProducts.PEPINILLO_PLUS -> stringResource(R.string.tier_name_pepinillo_plus)
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
                    // Safe locale-aware per-month equivalent for annual (#360)
                    subtitle = if (isAnnual && product.priceMicros > 0) {
                        val monthlyMicros = product.priceMicros / 12
                        val monthlyAmount = monthlyMicros / 1_000_000.0
                        val currencyCode = product.`package`.product.price.currencyCode
                        val monthlyStr = if (!currencyCode.isNullOrBlank()) {
                            runCatching {
                                val format = java.text.NumberFormat.getCurrencyInstance()
                                format.currency = java.util.Currency.getInstance(currencyCode)
                                format.format(monthlyAmount)
                            }.getOrElse {
                                product.formattedPrice.replace(Regex("[0-9]+([.,][0-9]+)?")) { "%.2f".format(monthlyAmount) }
                            }
                        } else {
                            product.formattedPrice.replace(Regex("[0-9]+([.,][0-9]+)?")) { "%.2f".format(monthlyAmount) }
                        }
                        stringResource(R.string.paywall_per_month, monthlyStr)
                    } else null,
                )
                Spacer(modifier = Modifier.height(8.dp))
            }
        } else {
            // Loading products or error state with retry button (#358)
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(min = 120.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center,
            ) {
                if (uiState.errorRes != null) {
                    Text(
                        text = stringResource(uiState.errorRes!!),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.error,
                        textAlign = TextAlign.Center,
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    TextButton(onClick = { viewModel.retryProducts() }) {
                        Text(stringResource(R.string.paywall_btn_retry))
                    }
                } else {
                    CircularProgressIndicator(
                        modifier = Modifier.size(24.dp),
                        strokeWidth = 2.dp,
                        color = MaterialTheme.colorScheme.primary,
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    TextButton(onClick = { viewModel.retryProducts() }) {
                        Text(stringResource(R.string.paywall_btn_retry))
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(8.dp))

        // Risk-reversal line — matches selected SKU type (#364)
        val riskReversalText = if (uiState.selectedProductId == PepinilloProducts.PEPINILLO_PLUS) {
            stringResource(R.string.paywall_risk_reversal_one_time)
        } else {
            stringResource(R.string.paywall_risk_reversal)
        }
        Text(
            text = riskReversalText,
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
            shape = PepinilloShapeTokens.button,
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
            enabled = !uiState.isPurchasing,
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

        Spacer(modifier = Modifier.height(12.dp))

        // ── LEGAL & SUBSCRIPTION LINKS (#361) ──
        fun openUrl(url: String) {
            try {
                context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
            } catch (_: Exception) {}
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = stringResource(R.string.support_btn_terms),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.primary,
                modifier = Modifier.clickable { openUrl("https://creapolis.dev/terms-of-use/") },
            )
            Text(
                text = "  •  ",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f),
            )
            Text(
                text = stringResource(R.string.support_btn_privacy),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.primary,
                modifier = Modifier.clickable { openUrl("https://creapolis.dev/privacy-policy/") },
            )
            Text(
                text = "  •  ",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f),
            )
            Text(
                text = stringResource(R.string.paywall_manage_subscription),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.primary,
                modifier = Modifier.clickable { openUrl("https://play.google.com/store/account/subscriptions") },
            )
        }

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
            .clip(PepinilloShapeTokens.card)
            .border(1.dp, accentColor.copy(alpha = 0.3f), PepinilloShapeTokens.card)
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
                        .clip(PepinilloShapeTokens.badge)
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
                .clip(PepinilloShapeTokens.badge)
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
                    .clip(PepinilloShapeTokens.badge)
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
            .clip(PepinilloShapeTokens.button)
            .border(
                width = if (isSelected) 2.dp else 1.dp,
                color = borderColor,
                shape = PepinilloShapeTokens.button,
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
                                .clip(PepinilloShapeTokens.badge)
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
