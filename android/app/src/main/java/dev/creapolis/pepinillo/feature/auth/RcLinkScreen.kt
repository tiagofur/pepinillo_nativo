package dev.creapolis.pepinillo.feature.auth

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.Link
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dev.creapolis.pepinillo.R
import dev.creapolis.pepinillo.ui.theme.PepinilloShapeTokens

/**
 * #953 RC license bridge (mirror of [EmailVerificationScreen]): enter the
 * single-use 6-digit code shown on app.pepinillo.app/account to bring a
 * native store purchase to the web account. Canonical entry-point label
 * fixed by the PR-2 dual review: "Usar mi compra en la Web".
 */
@Composable
fun RcLinkScreen(
    onNavigateBack: () -> Unit,
    viewModel: RcLinkViewModel = hiltViewModel(),
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val focusManager = LocalFocusManager.current

    LaunchedEffect(Unit) {
        viewModel.events.collect { event ->
            when (event) {
                RcLinkEvent.NavigateBack -> onNavigateBack()
            }
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        if (uiState.isLinked) {
            RcLinkSuccessContent(
                maskedEmail = uiState.successEmail.orEmpty(),
                onContinue = viewModel::onContinue,
            )
        } else {
            RcLinkClaimContent(
                uiState = uiState,
                onCodeChange = viewModel::onCodeChange,
                onClaim = {
                    focusManager.clearFocus()
                    viewModel.claim()
                },
            )
        }
    }
}

@Composable
private fun RcLinkClaimContent(
    uiState: RcLinkUiState,
    onCodeChange: (String) -> Unit,
    onClaim: () -> Unit,
) {
    Icon(
        imageVector = Icons.Rounded.Link,
        contentDescription = null,
        modifier = Modifier.size(56.dp),
        tint = MaterialTheme.colorScheme.primary,
    )

    Spacer(modifier = Modifier.height(16.dp))

    Text(
        text = stringResource(R.string.rc_link_title),
        style = MaterialTheme.typography.headlineLarge,
        fontWeight = FontWeight.Bold,
        color = MaterialTheme.colorScheme.primary,
        textAlign = TextAlign.Center,
    )

    Spacer(modifier = Modifier.height(8.dp))

    Text(
        text = stringResource(R.string.rc_link_desc),
        style = MaterialTheme.typography.bodyLarge,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        textAlign = TextAlign.Center,
    )

    Spacer(modifier = Modifier.height(32.dp))

    OutlinedTextField(
        value = uiState.code,
        onValueChange = onCodeChange,
        label = { Text(stringResource(R.string.rc_link_label_code)) },
        singleLine = true,
        keyboardOptions = KeyboardOptions(
            keyboardType = KeyboardType.Number,
        ),
        keyboardActions = KeyboardActions(onDone = { if (uiState.code.length == 6) onClaim() }),
        modifier = Modifier.fillMaxWidth(),
        shape = PepinilloShapeTokens.textField,
    )

    if (uiState.errorMessageRes != null) {
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = stringResource(uiState.errorMessageRes),
            color = MaterialTheme.colorScheme.error,
            style = MaterialTheme.typography.bodySmall,
            textAlign = TextAlign.Center,
        )
    }

    Spacer(modifier = Modifier.height(24.dp))

    Button(
        onClick = onClaim,
        modifier = Modifier
            .fillMaxWidth()
            .height(52.dp),
        enabled = !uiState.isLoading && uiState.code.length == 6,
        shape = PepinilloShapeTokens.button,
    ) {
        if (uiState.isLoading) {
            CircularProgressIndicator(
                color = MaterialTheme.colorScheme.onPrimary,
                strokeWidth = 2.dp,
                modifier = Modifier.size(24.dp),
            )
        } else {
            Text(stringResource(R.string.rc_link_btn_claim), style = MaterialTheme.typography.titleMedium)
        }
    }
}

@Composable
private fun RcLinkSuccessContent(
    maskedEmail: String,
    onContinue: () -> Unit,
) {
    Icon(
        imageVector = Icons.Rounded.CheckCircle,
        contentDescription = null,
        modifier = Modifier.size(72.dp),
        tint = MaterialTheme.colorScheme.primary,
    )

    Spacer(modifier = Modifier.height(16.dp))

    Text(
        text = stringResource(R.string.rc_link_success_title),
        style = MaterialTheme.typography.headlineLarge,
        fontWeight = FontWeight.Bold,
        color = MaterialTheme.colorScheme.primary,
        textAlign = TextAlign.Center,
    )

    Spacer(modifier = Modifier.height(8.dp))

    Text(
        text = stringResource(R.string.rc_link_success_body, maskedEmail),
        style = MaterialTheme.typography.bodyLarge,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        textAlign = TextAlign.Center,
    )

    Spacer(modifier = Modifier.height(32.dp))

    Button(
        onClick = onContinue,
        modifier = Modifier
            .fillMaxWidth()
            .height(52.dp),
        shape = PepinilloShapeTokens.button,
    ) {
        Text(stringResource(R.string.rc_link_btn_continue), style = MaterialTheme.typography.titleMedium)
    }
}
