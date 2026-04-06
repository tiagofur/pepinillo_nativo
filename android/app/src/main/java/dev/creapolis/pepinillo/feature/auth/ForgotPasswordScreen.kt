package dev.creapolis.pepinillo.feature.auth

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.Visibility
import androidx.compose.material.icons.rounded.VisibilityOff
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel

@Composable
fun ForgotPasswordScreen(
    onNavigateBack: () -> Unit,
    onResetSuccess: () -> Unit,
    viewModel: ForgotPasswordViewModel = hiltViewModel(),
) {
    val uiState by viewModel.uiState.collectAsState()

    LaunchedEffect(Unit) {
        viewModel.events.collect { event ->
            when (event) {
                is ForgotPasswordEvent.NavigateBack -> onNavigateBack()
                is ForgotPasswordEvent.ResetSuccess -> onResetSuccess()
            }
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        verticalArrangement = Arrangement.Top,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Spacer(modifier = Modifier.height(16.dp))

        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            IconButton(onClick = onNavigateBack) {
                Icon(
                    imageVector = Icons.AutoMirrored.Rounded.ArrowBack,
                    contentDescription = "Go back",
                )
            }
        }

        Spacer(modifier = Modifier.height(24.dp))

        when (uiState.step) {
            is ForgotPasswordStep.EnterEmail -> EnterEmailStep(
                uiState = uiState,
                onEmailChange = viewModel::onEmailChange,
                onSendCode = viewModel::sendCode,
            )
            is ForgotPasswordStep.EnterCode -> EnterCodeStep(
                uiState = uiState,
                onCodeChange = viewModel::onCodeChange,
                onNewPasswordChange = viewModel::onNewPasswordChange,
                onConfirmPasswordChange = viewModel::onConfirmPasswordChange,
                onTogglePasswordVisibility = viewModel::togglePasswordVisibility,
                onToggleConfirmPasswordVisibility = viewModel::toggleConfirmPasswordVisibility,
                onResetPassword = viewModel::resetPassword,
                onResendCode = viewModel::resendCode,
            )
        }
    }
}

@Composable
private fun EnterEmailStep(
    uiState: ForgotPasswordUiState,
    onEmailChange: (String) -> Unit,
    onSendCode: () -> Unit,
) {
    Text(
        text = "Forgot Password",
        style = MaterialTheme.typography.headlineLarge,
        fontWeight = FontWeight.Bold,
        color = MaterialTheme.colorScheme.primary,
    )

    Spacer(modifier = Modifier.height(8.dp))

    Text(
        text = "Enter your email and we'll send you a code to reset your password.",
        style = MaterialTheme.typography.bodyLarge,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
    )

    Spacer(modifier = Modifier.height(48.dp))

    OutlinedTextField(
        value = uiState.email,
        onValueChange = onEmailChange,
        label = { Text("Email") },
        singleLine = true,
        keyboardOptions = KeyboardOptions(
            keyboardType = KeyboardType.Email,
            imeAction = ImeAction.Done,
        ),
        keyboardActions = KeyboardActions(onDone = { onSendCode() }),
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
    )

    if (uiState.errorMessage != null) {
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = uiState.errorMessage,
            color = MaterialTheme.colorScheme.error,
            style = MaterialTheme.typography.bodySmall,
        )
    }

    Spacer(modifier = Modifier.height(24.dp))

    Button(
        onClick = onSendCode,
        modifier = Modifier
            .fillMaxWidth()
            .height(52.dp),
        enabled = !uiState.isLoading,
        shape = RoundedCornerShape(16.dp),
    ) {
        if (uiState.isLoading) {
            CircularProgressIndicator(
                color = MaterialTheme.colorScheme.onPrimary,
                strokeWidth = 2.dp,
                modifier = Modifier.size(24.dp),
            )
        } else {
            Text("Send Code", style = MaterialTheme.typography.titleMedium)
        }
    }
}

@Composable
private fun EnterCodeStep(
    uiState: ForgotPasswordUiState,
    onCodeChange: (String) -> Unit,
    onNewPasswordChange: (String) -> Unit,
    onConfirmPasswordChange: (String) -> Unit,
    onTogglePasswordVisibility: () -> Unit,
    onToggleConfirmPasswordVisibility: () -> Unit,
    onResetPassword: () -> Unit,
    onResendCode: () -> Unit,
) {
    Text(
        text = "Reset Password",
        style = MaterialTheme.typography.headlineLarge,
        fontWeight = FontWeight.Bold,
        color = MaterialTheme.colorScheme.primary,
    )

    Spacer(modifier = Modifier.height(8.dp))

    Text(
        text = "Enter the code we sent to ${uiState.email} and your new password.",
        style = MaterialTheme.typography.bodyLarge,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
    )

    Spacer(modifier = Modifier.height(48.dp))

    OutlinedTextField(
        value = uiState.code,
        onValueChange = onCodeChange,
        label = { Text("Verification Code") },
        singleLine = true,
        keyboardOptions = KeyboardOptions(
            keyboardType = KeyboardType.Number,
            imeAction = ImeAction.Next,
        ),
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
    )

    Spacer(modifier = Modifier.height(12.dp))

    OutlinedTextField(
        value = uiState.newPassword,
        onValueChange = onNewPasswordChange,
        label = { Text("New Password") },
        singleLine = true,
        visualTransformation = if (uiState.isPasswordVisible) VisualTransformation.None else PasswordVisualTransformation(),
        keyboardOptions = KeyboardOptions(
            keyboardType = KeyboardType.Password,
            imeAction = ImeAction.Next,
        ),
        trailingIcon = {
            IconButton(onClick = onTogglePasswordVisibility) {
                Icon(
                    if (uiState.isPasswordVisible) Icons.Rounded.VisibilityOff else Icons.Rounded.Visibility,
                    contentDescription = "Toggle password visibility",
                )
            }
        },
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
    )

    Spacer(modifier = Modifier.height(12.dp))

    OutlinedTextField(
        value = uiState.confirmPassword,
        onValueChange = onConfirmPasswordChange,
        label = { Text("Confirm Password") },
        singleLine = true,
        visualTransformation = if (uiState.isConfirmPasswordVisible) VisualTransformation.None else PasswordVisualTransformation(),
        keyboardOptions = KeyboardOptions(
            keyboardType = KeyboardType.Password,
            imeAction = ImeAction.Done,
        ),
        keyboardActions = KeyboardActions(onDone = { onResetPassword() }),
        trailingIcon = {
            IconButton(onClick = onToggleConfirmPasswordVisibility) {
                Icon(
                    if (uiState.isConfirmPasswordVisible) Icons.Rounded.VisibilityOff else Icons.Rounded.Visibility,
                    contentDescription = "Toggle confirm password visibility",
                )
            }
        },
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
    )

    if (uiState.errorMessage != null) {
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = uiState.errorMessage,
            color = MaterialTheme.colorScheme.error,
            style = MaterialTheme.typography.bodySmall,
        )
    }

    Spacer(modifier = Modifier.height(24.dp))

    Button(
        onClick = onResetPassword,
        modifier = Modifier
            .fillMaxWidth()
            .height(52.dp),
        enabled = !uiState.isLoading,
        shape = RoundedCornerShape(16.dp),
    ) {
        if (uiState.isLoading) {
            CircularProgressIndicator(
                color = MaterialTheme.colorScheme.onPrimary,
                strokeWidth = 2.dp,
                modifier = Modifier.size(24.dp),
            )
        } else {
            Text("Reset Password", style = MaterialTheme.typography.titleMedium)
        }
    }

    Spacer(modifier = Modifier.height(16.dp))

    TextButton(onClick = onResendCode) {
        Text(
            "Didn't receive the code? Resend",
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}
