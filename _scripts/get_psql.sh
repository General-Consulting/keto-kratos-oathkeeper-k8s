export PGPASSWORD=$(kubectl get secret postgresql -n default -o jsonpath="{.data.postgresql-password}" | base64 --decode)
echo "Forwarding port for PostgreSQL..."
nohup kubectl port-forward svc/postgresql 5432:5432 -n default &
PORT_FORWARD_PID=$!
echo "Port forwarding started with PID $PORT_FORWARD_PID"

sleep 3

psql -h localhost -p 5432 -U postgres

# Clean up port forwarding on disconnect
kill $PORT_FORWARD_PID
