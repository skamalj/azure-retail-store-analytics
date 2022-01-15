const cassandra = require('cassandra-driver');

// Record for testing
const samplerecords = [{"id": "abc", "name": "kamal4"}];

// Client is declared globally so that it can be used in the processRecords function
var client;
var connection;

// This functions get the connection details from SSM Parameter Store.
// It is called only once when the Lambda function is started.
// It is not called again when the Lambda function is invoked.
// It returns a connection promise which is used in the processRecords function.
async function connectDB(){
    if (connection) return connection;
     
    console.log("Reading environment variables")
    var ybRootCrt = process.env["yugabyte.root-crt"];
    var ybAdminUser = process.env["yugabyte.admin-user"];
    var ybAdminPassword = process.env["yugabyte.admin-password"];
    var ybHost= process.env["yugabyte.host"];

    var conn_params = [ybRootCrt, ybAdminUser, ybAdminPassword, ybHost];
    
    client = new cassandra.Client({
        contactPoints: [conn_params[3]],
        localDataCenter: 'eu-central-1',
        credentials: { username: conn_params[1], password: conn_params[2] },
        keyspace: 'kinesis',
        sslOptions: { ca: conn_params[0] }
    });

    //connect to Database
    connection = client.connect()
    return connection
}

// This function is called when the Lambda function is invoked.
// Function uses Promise.all to process the records in the batch and return a Promise.
// I could not make prepared statement option work with JSONB column, hence not used. 
async function processRecords(batch,context) {
    return connectDB()
        .then(() => {
            context.log("Inserting batch of size " + batch.length);
            const query = "INSERT INTO transactions (id,details) VALUES (?,?)";
            return Promise.all(batch.map(v => {
                // prepare option is not working with jsonb column
                return client.execute(query,[v.id, JSON.stringify(v)])}));
        }).then(result => {
            return context.log("Records created. Result Size: " + result.length);
        }).catch((err) => {
            return context.log("Error when inserting data "+err.stack);
        });
}


module.exports = async function (context, eventHubMessages) {
    context.log(`JavaScript eventhub trigger function called for message array ${eventHubMessages.length}`);

    await processRecords(eventHubMessages, context);
};

