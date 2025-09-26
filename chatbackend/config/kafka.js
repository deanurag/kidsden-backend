const {Kafka} = require("kafkajs");

let kafka = null;

if (process.env.KAFKA_DISABLED !== 'true') {
    kafka = new Kafka({
        brokers: [process.env.KAFKA_BROKERS || 'kafka:9092'],
    });
}

module.exports = kafka;