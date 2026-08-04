using System;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Pepinillo.Core.Data;

#nullable disable

namespace Pepinillo.Core.Migrations
{
    /// <inheritdoc />
    [DbContext(typeof(PepinilloDbContext))]
    [Migration("20260804180000_AddStreakProtectionSettings")]
    public partial class AddStreakProtectionSettings : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "StreakProtectionWeekStartUtc",
                table: "UserSettings",
                type: "TEXT",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "StreakProtectionUsesThisWeek",
                table: "UserSettings",
                type: "INTEGER",
                nullable: false,
                defaultValue: 0);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "StreakProtectionWeekStartUtc",
                table: "UserSettings");

            migrationBuilder.DropColumn(
                name: "StreakProtectionUsesThisWeek",
                table: "UserSettings");
        }
    }
}
