using TerraPlantarum.Application.Common.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace TerraPlantarum.Infrastructure.Persistence
{
    public class ApplicationDbContext(DbContextOptions<ApplicationDbContext> options) : DbContext(options), IApplicationDbContext
    {
        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
        }
    }
}
