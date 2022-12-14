const express = require("express");
const mysql = require("mysql");
const cors = require("cors");
const bodyParser = require("body-parser");
const dotenv = require("dotenv");
dotenv.config();

var pool = mysql.createPool({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  port: process.env.DB_PORT,
})
pool.getConnection((err,connection)=> {
  if(err)
  throw err;
  console.log('Database connected successfully');
  connection.release();
});


const PORT = process.env.APP_PORT || 3306;

const app = express();
app.use(cors());
app.use(bodyParser.json());

// var connection = mysql.createConnection({
//   host: process.env.DB_HOST,
//   user: process.env.DB_USER,
//   password: process.env.DB_PASSWORD,
//   database: process.env.DB_NAME,
//   port: process.env.DB_PORT,
// });

//Route
app.use(
  express.urlencoded({
    extended: true,
  })
);

app.post("/verifyCustomer", function (req, res) {
  console.log("se llama el endpoint");

  var email = req.body.email;
  var name = req.body.name;
  var lastName = req.body.lastName;
  const password = process.env.CUSTOMERS_TOKEN;

  const query = `SELECT * FROM uv_user where email = '${email}'`;
  pool.query(query, (err, results) => {
    if (err) throw err;
    if (results.length > 0) {
      res.json("usuario existe");
    } else {
      const createUserQuery = `INSERT INTO uv_user (email,proxy_id,password,first_name,last_name,is_enabled,verification_code,timezone,timeformat) VALUES ('${email}',null,'${password}','${name}','${lastName}',1,null,null,null)`;
      pool.query(createUserQuery, (err, results) => {
        if (err) {
          throw err;
        } else {
          const maxIdValueQuery = `SELECT id FROM uv_user where email='${email}'`;
          pool.query(maxIdValueQuery, function (err, result) {
            if (err) {
              throw err;
            } else {
              const maxIdValue =
                JSON.parse(JSON.stringify(result))[0]["id"];
              const createUserInstance = `INSERT INTO uv_user_instance (user_id, source, created_at, updated_at, is_active, is_verified, is_starred, supportRole_id) VALUES ( '${maxIdValue}', 'website', '2022-10-06 20:23:57', '2022-10-06 21:32:13', '1', '1', '0', '4')`;
              pool.query(createUserInstance, (err, results) => {
                if (err) {
                  throw err;
                } else {
                  res.json({ success: "200" });
                }
              });
            }
          });
        }
      });
    }
  });
});

// connection.connect((error) => {
//   if (error) throw error;
//   console.log("Database server running successfully!");
// });

app.listen(PORT, () => console.log("Server listening on port " + PORT));
