const express = require('express');
const app = express();
const PORT = 3001;

app.use(express.json());

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', service: 'user-service' });
});

// Get all users (dummy data)
app.get('/api/users', (req, res) => {
  res.json({
    users: [
      { id: 1, name: 'John Doe', email: 'john@example.com' },
      { id: 2, name: 'Jane Smith', email: 'jane@example.com' }
    ]
  });
});

// Create user
app.post('/api/users', (req, res) => {
  const { name, email } = req.body;
  res.status(201).json({
    id: 3,
    name,
    email,
    created: new Date()
  });
});

app.listen(PORT, () => {
  console.log(`🚀 User service running on port ${PORT}`);
});
