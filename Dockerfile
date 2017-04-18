FROM debian

RUN set -xe && \
    apt-get -qq update && \
    apt-get -qq install \
        awscli \
        mysql-client \
        curl \
        --no-install-recommends && \
    curl -sSL https://github.com/jwilder/dockerize/releases/download/v0.2.0/dockerize-linux-amd64-v0.2.0.tar.gz | \
        tar -C /usr/local/bin -xzv && \
    mkdir -p /backups && \
    apt-get purge -qq --auto-remove \
        -o APT::AutoRemove::RecommendsImportant=false \
        -o APT::AutoRemove::SuggestsImportant=false \
        curl \
        && \
    apt-get clean && \
    rm -r /var/lib/apt/lists/* && \
    true

COPY my.cnf /root/my.cnf.template

ENV DUMP_FLAGS --quote-names --opt --dump-date --single-transaction --events --routines --triggers
CMD set -xe && \
    dockerize -wait tcp://${DB_HOST:-db}:3306 -timeout 120s -template /root/my.cnf.template:/root/.my.cnf && \
    databases=`mysql --batch --skip-column-names -e 'SHOW DATABASES;' | grep -v 'mysql\|information_schema\|performance_schema\|sys'` && \
    for database in $databases; do \
        mysqldump ${DUMP_FLAGS} --databases $database --result-file=/backups/$database.sql; \
        gzip -9 /backups/$database.sql; \
    done && \
    aws s3 sync /backups/ s3://${AWS_S3_BUCKET_NAME}/$(date +%Y)/$(date +%Y-%m)/$(date +%Y-%m-%d)/ && \
    true
