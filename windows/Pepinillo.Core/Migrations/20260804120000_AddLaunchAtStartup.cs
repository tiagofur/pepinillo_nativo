using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Pepinillo.Core.Migrations
{
    /// <inheritdoc />
    public partial class AddLaunchAtStartup : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "LaunchAtWindowsStartup",
                table: "UserSettings",
                type: "INTEGER",
                nullable: false,
                defaultValue: false);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "LaunchAtWindowsStartup",
                table: "UserSettings");
        }
    }
}
