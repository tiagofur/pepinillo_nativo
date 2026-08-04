using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Pepinillo.Core.Data;

#nullable disable

namespace Pepinillo.Core.Migrations
{
    /// <inheritdoc />
    [DbContext(typeof(PepinilloDbContext))]
    [Migration("20260804220000_AddMiniTimerBounds")]
    public partial class AddMiniTimerBounds : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "MiniTimerX",
                table: "UserSettings",
                type: "INTEGER",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "MiniTimerY",
                table: "UserSettings",
                type: "INTEGER",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "MiniTimerWidth",
                table: "UserSettings",
                type: "INTEGER",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "MiniTimerHeight",
                table: "UserSettings",
                type: "INTEGER",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "MiniTimerX",
                table: "UserSettings");

            migrationBuilder.DropColumn(
                name: "MiniTimerY",
                table: "UserSettings");

            migrationBuilder.DropColumn(
                name: "MiniTimerWidth",
                table: "UserSettings");

            migrationBuilder.DropColumn(
                name: "MiniTimerHeight",
                table: "UserSettings");
        }
    }
}
