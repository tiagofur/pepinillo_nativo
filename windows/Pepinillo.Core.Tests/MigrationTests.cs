using System;
using System.IO;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Pepinillo.Core.Data;
using Pepinillo.Core.Models;
using Xunit;

namespace Pepinillo.Core.Tests;

public class MigrationTests
{
    [Fact]
    public async Task MigrateAsync_CreatesSchema_AndAllowsCrud()
    {
        var path = Path.Combine(Path.GetTempPath(), $"pepinillo-mig-{Guid.NewGuid():N}.db");
        try
        {
            var options = new DbContextOptionsBuilder<PepinilloDbContext>()
                .UseSqlite($"Data Source={path}")
                .Options;

            await using (var db = new PepinilloDbContext(options))
            {
                await db.Database.MigrateAsync();

                db.TaskItems.Add(new TaskItem { Title = "Migrated task" });
                await db.SaveChangesAsync();
            }

            await using (var db = new PepinilloDbContext(options))
            {
                Assert.Equal(1, await db.TaskItems.CountAsync());
                Assert.True(await db.Database.CanConnectAsync());
            }
        }
        finally
        {
            try
            {
                if (File.Exists(path))
                    File.Delete(path);
            }
            catch
            {
                // temp cleanup best-effort
            }
        }
    }
}
