namespace TerraPlantarum.Application.Common.Interfaces;

public interface IApplicationDbContext
{
    // Add DbSet<T> properties here as you introduce entities in TerraPlantarum.Domain.
    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);
}
