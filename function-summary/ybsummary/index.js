const { Pool, Client } = require('pg')

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

    client = new Client({
        host: conn_params[3],
        user: conn_params[1], 
        password: conn_params[2],
        database: 'yugabyte',
        port: 5433,
        ssl: {
            rejectUnauthorized: false,
            ca: conn_params[0] 
        }
    });

    //Connect to Database and return promise
    connection = client.connect()
    return connection
}

// postgres nodejs library has a bug that causes it to not return a promise, hence the async/await
function processRecords(batch, context) {
    return connectDB()
        .then(async () => {
            context.log("Processing Records");
            const query = "INSERT INTO summary VALUES ($1,$2,$3,$4,$5)";
            var rec_count = 0;
            for (v of batch) {
                var v_json = v;
                await client.query(query, [v_json.CurrentTime, v_json.window_time_per_store_prod,
                 v_json.store_id, v_json.product_name,
                v_json.total_sale]);
                context.log(`Inserted record-${++rec_count}: ${JSON.stringify(v)}`);
            }
        }).catch ((err) => {
            context.log("Error when inserting records:  " + err.stack);
        });
}

module.exports = async function (context, eventHubMessages) {
    context.log(`Function called to insert ${eventHubMessages.length} records`);

    await processRecords(eventHubMessages, context);
};