package dev.creapolis.pepinillo.feature.auth.components

import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable

@Composable
fun DataMergeDialog(
    onMerge: () -> Unit,
    onUseAccountOnly: () -> Unit,
    onDismiss: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Text(
                text = "Local Data Found",
                style = MaterialTheme.typography.headlineSmall,
            )
        },
        text = {
            Text(
                text = "You have data on this device that hasn't been synced. " +
                    "Would you like to merge it with your account, or start fresh with your account data?",
                style = MaterialTheme.typography.bodyMedium,
            )
        },
        confirmButton = {
            TextButton(onClick = onMerge) {
                Text("Merge Data")
            }
        },
        dismissButton = {
            TextButton(onClick = onUseAccountOnly) {
                Text("Use Account Only")
            }
        },
    )
}
