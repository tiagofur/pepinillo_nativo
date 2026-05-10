package dev.creapolis.pepinillo.feature.auth.components

import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable

import androidx.compose.ui.res.stringResource
import dev.creapolis.pepinillo.R

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
                text = stringResource(R.string.merge_title),
                style = MaterialTheme.typography.headlineSmall,
            )
        },
        text = {
            Text(
                text = stringResource(R.string.merge_desc),
                style = MaterialTheme.typography.bodyMedium,
            )
        },
        confirmButton = {
            TextButton(onClick = onMerge) {
                Text(stringResource(R.string.merge_btn_merge))
            }
        },
        dismissButton = {
            TextButton(onClick = onUseAccountOnly) {
                Text(stringResource(R.string.merge_btn_account_only))
            }
        },
    )
}
