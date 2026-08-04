using System;
using System.IO;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace Pepinillo.Core.Data;

/// <summary>
/// Design-time factory for <c>dotnet ef migrations</c> (no WinUI runtime required).
/// </summary>
public sealed class PepinilloDbContextFactory : IDesignTimeDbContextFactory<PepinilloDbContext>
{
    public PepinilloDbContext CreateDbContext(string[] args)
    {
        var path = Path.Combine(Path.GetTempPath(), "pepinillo-design.db");
        var options = new DbContextOptionsBuilder<PepinilloDbContext>()
            .UseSqlite($"Data Source={path}")
            .Options;
        return new PepinilloDbContext(options);
    }
}
