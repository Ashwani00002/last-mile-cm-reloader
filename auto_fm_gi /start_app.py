from configurations import setup_logging
from consumers.package_kafka_consumer import consume_from_kafka


def consume_package_stream():
    setup_logging()
    consume_from_kafka()


if __name__ == "__main__":
    consume_package_stream()