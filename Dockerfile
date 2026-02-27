# Build stage
FROM mcr.microsoft.com/dotnet/sdk:6.0 AS build
WORKDIR /app

# Copy project file and restore dependencies (build context is the repo root)
COPY src/*.csproj ./
RUN dotnet restore

# Copy source and build
COPY src/ ./
RUN dotnet publish -c Release -o /app/publish --no-restore

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:6.0 AS runtime
WORKDIR /app

# Copy published output
COPY --from=build /app/publish .

# Expose the port ASP.NET Core listens on
EXPOSE 8080
ENV ASPNETCORE_URLS=http://+:8080

ENTRYPOINT ["dotnet", "ZavaStorefront.dll"]
