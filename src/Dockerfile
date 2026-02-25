# ============================================================================
# ZavaStorefront Dockerfile
# Multi-stage build for ASP.NET Core 6.0 application
# 
# NOTE: This Dockerfile is designed to be built using:
#   - Azure Container Registry Tasks (az acr build)
#   - GitHub Actions
# No local Docker installation is required.
# ============================================================================

# Stage 1: Build
FROM mcr.microsoft.com/dotnet/sdk:6.0 AS build
WORKDIR /src

# Copy project files and restore dependencies
COPY ["ZavaStorefront.csproj", "./"]
RUN dotnet restore "ZavaStorefront.csproj"

# Copy remaining source code
COPY . .

# Build the application
RUN dotnet build "ZavaStorefront.csproj" -c Release -o /app/build

# Stage 2: Publish
FROM build AS publish
RUN dotnet publish "ZavaStorefront.csproj" -c Release -o /app/publish /p:UseAppHost=false

# Stage 3: Runtime
FROM mcr.microsoft.com/dotnet/aspnet:6.0 AS final
WORKDIR /app

# Expose port 8080 (Azure App Service default)
EXPOSE 8080
ENV ASPNETCORE_URLS=http://+:8080

# Copy published output
COPY --from=publish /app/publish .

# Set entry point
ENTRYPOINT ["dotnet", "ZavaStorefront.dll"]
