using System;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Pepinillo.Core.Data;

#nullable disable

namespace Pepinillo.Core.Migrations
{
    /// <inheritdoc />
    [DbContext(typeof(PepinilloDbContext))]
    [Migration("20260804160000_AddDeviceIdAndLastSyncAt")]
    public partial class AddDeviceIdAndLastSyncAt : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "DeviceId",
                table: "UserSettings",
                type: "TEXT",
                maxLength: 64,
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "LastSyncAtUtc",
                table: "UserSettings",
                type: "TEXT",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "DeviceId",
                table: "UserSettings");

            migrationBuilder.DropColumn(
                name: "LastSyncAtUtc",
                table: "UserSettings");
        }
    }
}
