using System;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Pepinillo.Core.Data;

#nullable disable

namespace Pepinillo.Core.Migrations
{
    /// <inheritdoc />
    [DbContext(typeof(PepinilloDbContext))]
    [Migration("20260804210000_AddPlannedTimeBlocks")]
    public partial class AddPlannedTimeBlocks : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "PlannedTimeBlocks",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    StartAtUtc = table.Column<DateTime>(type: "TEXT", nullable: false),
                    DurationMinutes = table.Column<int>(type: "INTEGER", nullable: false),
                    Title = table.Column<string>(type: "TEXT", maxLength: 256, nullable: false),
                    TaskItemId = table.Column<Guid>(type: "TEXT", nullable: true),
                    IsCompleted = table.Column<bool>(type: "INTEGER", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "TEXT", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PlannedTimeBlocks", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_PlannedTimeBlocks_StartAtUtc",
                table: "PlannedTimeBlocks",
                column: "StartAtUtc");

            migrationBuilder.CreateIndex(
                name: "IX_PlannedTimeBlocks_TaskItemId",
                table: "PlannedTimeBlocks",
                column: "TaskItemId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "PlannedTimeBlocks");
        }
    }
}
