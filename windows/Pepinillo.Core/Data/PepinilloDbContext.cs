using Microsoft.EntityFrameworkCore;
using Pepinillo.Core.Models;

namespace Pepinillo.Core.Data;

public class PepinilloDbContext : DbContext
{
    public DbSet<FocusSession> FocusSessions => Set<FocusSession>();
    public DbSet<TaskItem> TaskItems => Set<TaskItem>();

    public PepinilloDbContext(DbContextOptions<PepinilloDbContext> options) : base(options)
    {
    }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.Entity<FocusSession>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Mode).HasConversion<string>();
        });

        modelBuilder.Entity<TaskItem>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Title).IsRequired();
            entity.HasMany(e => e.SubTasks)
                  .WithOne()
                  .HasForeignKey(e => e.ParentTaskId)
                  .OnDelete(DeleteBehavior.Cascade);
        });
    }
}
