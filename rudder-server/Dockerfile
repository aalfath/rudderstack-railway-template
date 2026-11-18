# RudderStack data plane (rudder-server), official image pinned by version and digest.
FROM rudderlabs/rudder-server:1.93.0@sha256:35425ca909205c828254d51743e4e67c648ebbe05aea876c73ea24b118105c4a

COPY railway-start.sh /railway-start.sh
RUN chmod 755 /railway-start.sh

ENV PORT=8080 \
    RUDDER_DATA_DIR=/data
EXPOSE 8080

# railway-start.sh prepares the config, then hands over to upstream's own entrypoint.
ENTRYPOINT ["/railway-start.sh"]
CMD ["/rudder-server"]
