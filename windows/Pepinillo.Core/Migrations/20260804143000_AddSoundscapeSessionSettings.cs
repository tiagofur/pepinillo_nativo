using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Pepinillo.Core.Data;

#nullable disable

namespace Pepinillo.Core.Migrations
{
    /// <inheritdoc />
    [DbContext(typeof(PepinilloDbContext))]
    [Migration("20260804143000_AddSoundscapeSessionSettings")]
    public partial class AddSoundscapeSessionSettings : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "AutoPlaySoundscapeOnFocus",
                table: "UserSettings",
                type: "INTEGER",
                nullable: false,
                defaultValue: true);

            migrationBuilder.AddColumn<string>(
                name: "PreferredSoundscapeId",
                table: "UserSettings",
                type: "TEXT",
                maxLength: 64,
                nullable: true,
                defaultValue: "rain");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "AutoPlaySoundscapeOnFocus",
                table: "UserSettings");

            migrationBuilder.DropColumn(
                name: "PreferredSoundscapeId",
                table: "UserSettings");
        }
    }
}
