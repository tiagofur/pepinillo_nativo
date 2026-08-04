using Microsoft.EntityFrameworkCore;
using Pepinillo.Core.Models;

namespace Pepinillo.Core.Data;

/// <summary>
/// Local SQLite store. EnsureCreated is used at launch — it does NOT migrate existing databases.
/// After schema changes (new columns), delete pepinillo.db from LocalFolder (or app data) so EnsureCreated can recreate.
/// </summary>
public class PepinilloDbContext : DbContext
{
    public DbSet<FocusSession> FocusSessions => Set<FocusSession>();
    public DbSet<TaskItem> TaskItems => Set<TaskItem>();
    public DbSet<UserSettings> UserSettings => Set<UserSettings>();

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
            entity.Property(e => e.JournalNote).HasMaxLength(4000);
        });

        modelBuilder.Entity<TaskItem>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Title).IsRequired();
            entity.Property(e => e.EnergyLevel).HasMaxLength(32);
            entity.Property(e => e.RecurrenceRule).HasMaxLength(128);
            entity.HasMany(e => e.SubTasks)
                  .WithOne()
                  .HasForeignKey(e => e.ParentTaskId)
                  .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<UserSettings>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.SelectedTheme).HasMaxLength(64);
            entity.Property(e => e.PreferredLanguage).HasMaxLength(16);
        });
    }
}
