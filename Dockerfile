FROM swift:6.3.3-noble AS builder

WORKDIR /build

COPY Package.swift Package.resolved ./
RUN swift package resolve

COPY Sources ./Sources
COPY Tests ./Tests
RUN swift build -c release --jobs 2

FROM swift:6.3.3-noble-slim AS runtime

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates tar \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --system --uid 10001 --create-home aanbiedingspan

WORKDIR /app

COPY --from=builder /build/.build/release /app/.build/release
COPY Public /app/Public
COPY Resources /app/Resources

RUN mkdir -p /app/Public/uploads/recipes \
    && chown -R aanbiedingspan:aanbiedingspan /app

USER aanbiedingspan

EXPOSE 8080

ENTRYPOINT ["/app/.build/release/Run"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]
