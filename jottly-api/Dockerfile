FROM norionomura/swift:swift-4.1-branch

RUN apt-get -qq update
RUN apt-get install -yq libssl-dev
RUN rm /etc/apt/apt.conf.d/docker-gzip-indexes
RUN apt-get purge apt-show-versions
RUN rm /var/lib/apt/lists/*lz4
RUN apt-get -o Acquire::GzipIndexes=false update
RUN apt-get install -yq apt-show-versions
RUN apt-show-versions libssl-dev

WORKDIR /app

COPY ./Public Public/
COPY ./Package.swift Package.swift
COPY ./Package.resolved Package.resolved
COPY ./Tests Tests/
COPY ./Sources Sources/
COPY ./.build .build/

RUN swift build -c release

RUN useradd jottly && chown -R jottly /app
USER jottly

EXPOSE 8080

ENV PATH /app/.build/release:$PATH

ENTRYPOINT [".build/release/Run"]
CMD ["--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]
