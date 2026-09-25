FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /

COPY ["src/TerraPlantarum.Api/TerraPlantarum.Api.csproj", "src/TerraPlantarum.Api/"]
COPY ["src/TerraPlantarum.Application/TerraPlantarum.Application.csproj", "src/TerraPlantarum.Application/"]
COPY ["src/TerraPlantarum.Domain/TerraPlantarum.Domain.csproj", "src/TerraPlantarum.Domain/"]
COPY ["src/TerraPlantarum.Infrastructure/TerraPlantarum.Infrastructure.csproj", "src/TerraPlantarum.Infrastructure/"]

RUN dotnet restore "src/TerraPlantarum.Api/TerraPlantarum.Api.csproj"

COPY . .

WORKDIR "/src/TerraPlantarum.Api"
RUN dotnet publish "TerraPlantarum.Api.csproj" -c Release -o /publish


FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
WORKDIR /app
COPY --from=build /publish .
ENTRYPOINT ["dotnet", "TerraPlantarum.Api.dll"]
