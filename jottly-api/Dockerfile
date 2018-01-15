FROM swift:4.0

ADD ./ /app
WORKDIR /app

RUN useradd jottly && chown -R jottly /app
USER jottly

RUN swift build -c release
ENV PATH /app/.build/release:$PATH
CMD .build/release/Run --env=production
