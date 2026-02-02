const express = require("express");

const app = express();
const PORT = 3000;

app.get("/health", (req, res) => {
  res.json({ status: "order-service up" });
});

app.listen(PORT, () => {
  console.log(`Order service running on port ${PORT}`);
});
