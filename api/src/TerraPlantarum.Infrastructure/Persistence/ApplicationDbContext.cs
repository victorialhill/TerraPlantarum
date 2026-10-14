using Microsoft.EntityFrameworkCore;
using TerraPlantarum.Application.Common.Interfaces;

namespace TerraPlantarum.Infrastructure.Persistence
{
    public class ApplicationDbContext(DbContextOptions<ApplicationDbContext> options) : DbContext(options), IApplicationDbContext
    {
        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
        }
    }
}
