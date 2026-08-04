using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Pepinillo.Core.Data;

#nullable disable

namespace Pepinillo.Core.Migrations
{
    /// <inheritdoc />
    [DbContext(typeof(PepinilloDbContext))]
    [Migration("20260804200000_AddOnboardingSettings")]
    public partial class AddOnboardingSettings : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "HasCompletedOnboarding",
                table: "UserSettings",
                type: "INTEGER",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<string>(
                name: "PreferredFocusMode",
                table: "UserSettings",
                type: "TEXT",
                maxLength: 32,
                nullable: false,
                defaultValue: "Pomodoro");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "HasCompletedOnboarding",
                table: "UserSettings");

            migrationBuilder.DropColumn(
                name: "PreferredFocusMode",
                table: "UserSettings");
        }
    }
}
