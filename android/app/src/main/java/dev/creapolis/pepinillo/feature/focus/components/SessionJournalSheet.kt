package dev.creapolis.pepinillo.feature.focus.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import dev.creapolis.pepinillo.R

private data class RatingOption(
    val id: Int,
    val emoji: String,
    val labelResId: Int,
)

private val ratingOptions = listOf(
    RatingOption(1, "\uD83D\uDE1E", R.string.journal_rating_rough),   // 😞
    RatingOption(2, "\uD83D\uDE10", R.string.journal_rating_meh),     // 😐
    RatingOption(3, "\uD83D\uDE42", R.string.journal_rating_okay),    // 🙂
    RatingOption(4, "\uD83D\uDE0A", R.string.journal_rating_good),    // 😊
    RatingOption(5, "\uD83D\uDD25", R.string.journal_rating_great),   // 🔥
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SessionJournalSheet(
    onSave: (note: String?, rating: Int?) -> Unit,
    onSkip: () -> Unit,
    onDismiss: () -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var selectedRating by remember { mutableIntStateOf(0) }
    var journalNote by remember { mutableStateOf("") }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            // Header
            Text(
                text = stringResource(R.string.journal_session_complete),
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
            )
            Spacer(modifier = Modifier.height(24.dp))

            // Rating section
            Text(
                text = stringResource(R.string.journal_how_was_focus),
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
            )
            Spacer(modifier = Modifier.height(12.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceEvenly,
            ) {
                ratingOptions.forEach { option ->
                    val isSelected = selectedRating == option.id
                    val label = stringResource(option.labelResId)
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        modifier = Modifier
                            .clip(RoundedCornerShape(12.dp))
                            .then(
                                if (isSelected) {
                                    Modifier
                                        .background(MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.3f))
                                        .border(2.dp, MaterialTheme.colorScheme.primary, RoundedCornerShape(12.dp))
                                } else {
                                    Modifier
                                },
                            )
                            .clickable {
                                selectedRating = if (selectedRating == option.id) 0 else option.id
                            }
                            .padding(8.dp)
                            .semantics { contentDescription = "$label, ${option.id} out of 5" },
                    ) {
                        Text(
                            text = option.emoji,
                            fontSize = 28.sp,
                        )
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = label,
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(24.dp))

            // Note section
            Text(
                text = stringResource(R.string.journal_quick_reflection),
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.fillMaxWidth(),
            )
            Spacer(modifier = Modifier.height(8.dp))

            OutlinedTextField(
                value = journalNote,
                onValueChange = { if (it.length <= 500) journalNote = it },
                modifier = Modifier.fillMaxWidth(),
                placeholder = { Text(stringResource(R.string.journal_placeholder)) },
                minLines = 3,
                maxLines = 6,
                shape = RoundedCornerShape(12.dp),
            )
            Text(
                text = "${journalNote.length}/500",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 4.dp),
                textAlign = TextAlign.End,
            )

            Spacer(modifier = Modifier.height(24.dp))

            // Action buttons
            Button(
                onClick = {
                    onSave(
                        journalNote.ifBlank { null },
                        if (selectedRating > 0) selectedRating else null,
                    )
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(48.dp),
                shape = RoundedCornerShape(24.dp),
            ) {
                Text(
                    text = stringResource(R.string.journal_save),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                )
            }

            TextButton(
                onClick = onSkip,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(
                    text = stringResource(R.string.journal_skip),
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            Spacer(modifier = Modifier.height(16.dp))
        }
    }
}
