# P1 guided packaging recipe (you own your copy). Explain each line in your review request.
# Base: the cached ASP.NET 10.0.12 runtime, pinned by digest (build with --pull=never; nothing is downloaded).
FROM mcr.microsoft.com/dotnet/aspnet:10.0.12@sha256:222759b391a1aaf241166672c8f99b2d4ada452e7b5319f3c6e8f265a37b5ad4

WORKDIR /app

# COPY: only the published output enters the image (no source, no runtime.env, no credentials).
COPY publish/ ./

# Listener: port 8080 inside the container (the Service targets the named port http = 8080).
ENV ASPNETCORE_URLS=http://0.0.0.0:8080
EXPOSE 8080

# Entrypoint: start the packaged foundation page + API.
ENTRYPOINT ["dotnet", "Foundation.dll"]
