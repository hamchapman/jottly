FROM norionomura/swift:swift-4.1-branch

RUN apt-get -qq update
RUN apt-get install -yq libssl-dev

WORKDIR /app

COPY ./Public Public/
COPY ./Package.swift Package.swift
COPY ./Package.resolved Package.resolved
COPY ./Tests Tests/
COPY ./Sources Sources/

RUN swift package resolve
RUN swift build -c release

EXPOSE 8080

ENV PATH /app/.build/release:$PATH

ENTRYPOINT [".build/release/Run"]
CMD ["--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]
