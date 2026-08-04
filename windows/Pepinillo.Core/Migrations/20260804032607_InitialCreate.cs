using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Pepinillo.Core.Migrations
{
    /// <inheritdoc />
    public partial class InitialCreate : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "FocusSessions",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    Mode = table.Column<string>(type: "TEXT", nullable: false),
                    TargetDurationSeconds = table.Column<int>(type: "INTEGER", nullable: false),
                    ElapsedSeconds = table.Column<int>(type: "INTEGER", nullable: false),
                    TaskItemId = table.Column<Guid>(type: "TEXT", nullable: true),
                    StartedAt = table.Column<DateTime>(type: "TEXT", nullable: false),
                    CompletedAt = table.Column<DateTime>(type: "TEXT", nullable: true),
                    IsCompleted = table.Column<bool>(type: "INTEGER", nullable: false),
                    IsSynced = table.Column<bool>(type: "INTEGER", nullable: false),
                    JournalNote = table.Column<string>(type: "TEXT", maxLength: 4000, nullable: true),
                    EnergyRating = table.Column<int>(type: "INTEGER", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_FocusSessions", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "TaskItems",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    Title = table.Column<string>(type: "TEXT", nullable: false),
                    Description = table.Column<string>(type: "TEXT", nullable: true),
                    EstimatedMinutes = table.Column<int>(type: "INTEGER", nullable: false),
                    CompletedMinutes = table.Column<int>(type: "INTEGER", nullable: false),
                    Priority = table.Column<int>(type: "INTEGER", nullable: false),
                    EnergyLevel = table.Column<string>(type: "TEXT", maxLength: 32, nullable: false),
                    EstimatedPomodoros = table.Column<int>(type: "INTEGER", nullable: false),
                    CompletedPomodoros = table.Column<int>(type: "INTEGER", nullable: false),
                    IsCompleted = table.Column<bool>(type: "INTEGER", nullable: false),
                    DueDate = table.Column<DateTime>(type: "TEXT", nullable: true),
                    ParentTaskId = table.Column<Guid>(type: "TEXT", nullable: true),
                    RecurrenceRule = table.Column<string>(type: "TEXT", maxLength: 128, nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "TEXT", nullable: false),
                    IsSynced = table.Column<bool>(type: "INTEGER", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TaskItems", x => x.Id);
                    table.ForeignKey(
                        name: "FK_TaskItems_TaskItems_ParentTaskId",
                        column: x => x.ParentTaskId,
                        principalTable: "TaskItems",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "UserSettings",
                columns: table => new
                {
                    Id = table.Column<int>(type: "INTEGER", nullable: false)
                        .Annotation("Sqlite:Autoincrement", true),
                    PomodoroFocusMinutes = table.Column<int>(type: "INTEGER", nullable: false),
                    ShortBreakMinutes = table.Column<int>(type: "INTEGER", nullable: false),
                    LongBreakMinutes = table.Column<int>(type: "INTEGER", nullable: false),
                    LongBreakInterval = table.Column<int>(type: "INTEGER", nullable: false),
                    FlowtimeTargetMinutes = table.Column<int>(type: "INTEGER", nullable: false),
                    TimeBlockingMinutes = table.Column<int>(type: "INTEGER", nullable: false),
                    AutoStartBreaks = table.Column<bool>(type: "INTEGER", nullable: false),
                    AutoStartFocusSessions = table.Column<bool>(type: "INTEGER", nullable: false),
                    EnableWindowsDoNotDisturbSync = table.Column<bool>(type: "INTEGER", nullable: false),
                    MinimizeToSystemTrayOnClose = table.Column<bool>(type: "INTEGER", nullable: false),
                    EnableToastNotifications = table.Column<bool>(type: "INTEGER", nullable: false),
                    EnableTickingSound = table.Column<bool>(type: "INTEGER", nullable: false),
                    TickingVolume = table.Column<double>(type: "REAL", nullable: false),
                    EnableSoundscapes = table.Column<bool>(type: "INTEGER", nullable: false),
                    SoundscapesMasterVolume = table.Column<double>(type: "REAL", nullable: false),
                    SelectedTheme = table.Column<string>(type: "TEXT", maxLength: 64, nullable: false),
                    UseMicaBackdrop = table.Column<bool>(type: "INTEGER", nullable: false),
                    CompactMiniTimerAlwaysOnTop = table.Column<bool>(type: "INTEGER", nullable: false),
                    PlayPauseHotkey = table.Column<string>(type: "TEXT", nullable: false),
                    SkipHotkey = table.Column<string>(type: "TEXT", nullable: false),
                    MiniTimerHotkey = table.Column<string>(type: "TEXT", nullable: false),
                    PreferredLanguage = table.Column<string>(type: "TEXT", maxLength: 16, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_UserSettings", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_TaskItems_ParentTaskId",
                table: "TaskItems",
                column: "ParentTaskId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "FocusSessions");

            migrationBuilder.DropTable(
                name: "TaskItems");

            migrationBuilder.DropTable(
                name: "UserSettings");
        }
    }
}
