using TerraPlantarum.Application.Common.Behaviors;
using TerraPlantarum.Application.Common.Exceptions;
using TerraPlantarum.Infrastructure;
using TerraPlantarum.Infrastructure.Persistence;
using FluentValidation;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.EntityFrameworkCore;
var builder = WebApplication.CreateBuilder(args);

// Trust the X-Forwarded-For / X-Forwarded-Proto headers sent by the reverse proxy
// (e.g. Railway, Caddy). Without this, UseHttpsRedirection sees every request as HTTP
// and issues an infinite redirect loop.
builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
    // Clear the default KnownNetworks/KnownProxies so any upstream proxy is trusted.
    // Only safe when the API isn't directly reachable from outside the proxy's network.
    options.KnownIPNetworks.Clear();
    options.KnownProxies.Clear();
});

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.AddInfrastructure(builder.Configuration);
builder.Services.AddMediatR(cfg =>
{
    cfg.RegisterServicesFromAssembly(typeof(TerraPlantarum.Application.AssemblyMarker).Assembly);
    cfg.AddOpenBehavior(typeof(ValidationBehavior<,>));
});
builder.Services.AddValidatorsFromAssembly(typeof(TerraPlantarum.Application.AssemblyMarker).Assembly);
builder.Services.AddControllers()
    .AddJsonOptions(options =>
    {
        options.JsonSerializerOptions.ReferenceHandler = System.Text.Json.Serialization.ReferenceHandler.IgnoreCycles;
        options.JsonSerializerOptions.DefaultIgnoreCondition = System.Text.Json.Serialization.JsonIgnoreCondition.WhenWritingNull;
    });

// Origins are read from config so they can be overridden via env vars in production.
// appsettings.json ships localhost defaults for local dev.
// Production: set  Cors__AllowedOrigins__0=https://yourapp.example.com  in your host's env vars.
var allowedOrigins = builder.Configuration
    .GetSection("Cors:AllowedOrigins")
    .Get<string[]>() ?? [];

builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        if (allowedOrigins.Length > 0)
            policy.WithOrigins(allowedOrigins).AllowAnyMethod().AllowAnyHeader();
    });
});

// Bind all interfaces inside the container. If you isolate the API behind Docker
// networking (only a reverse proxy reaches it), this is safe as-is.
builder.WebHost.UseUrls($"http://+:{Environment.GetEnvironmentVariable("PORT") ?? "8080"}");

var app = builder.Build();

using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
    db.Database.Migrate();
}

// Must be first so all subsequent middleware sees the corrected scheme/IP.
app.UseForwardedHeaders();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseCors();

app.Use(async (context, next) =>
{
    try
    {
        await next();
    }
    catch (ValidationException ex)
    {
        context.Response.StatusCode = StatusCodes.Status400BadRequest;
        await context.Response.WriteAsJsonAsync(ex.Errors.Select(e => new { e.PropertyName, e.ErrorMessage }));
    }
    catch (KeyNotFoundException ex)
    {
        context.Response.StatusCode = StatusCodes.Status404NotFound;
        await context.Response.WriteAsJsonAsync(new { message = ex.Message });
    }
    catch (ConflictException ex)
    {
        context.Response.StatusCode = StatusCodes.Status409Conflict;
        await context.Response.WriteAsJsonAsync(new { message = ex.Message });
    }
});
// No UseHttpsRedirection: if TLS is terminated at a reverse proxy and the API is reached
// over plain HTTP on an internal network, redirecting here would break that. Remove this
// comment and add UseHttpsRedirection() if the API is reachable directly.

app.UseAuthorization();
app.MapControllers();

app.Run();
