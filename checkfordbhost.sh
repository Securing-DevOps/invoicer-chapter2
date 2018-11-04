while true; do
   aws rds describe-db-instances \
      --db-instance-identifier invoicer-db > /tmp/invoicer-db.json
   dbhost=$(jq -r '.DBInstances[0].Endpoint.Address' /tmp/invoicer-db.json)
   if [ "$dbhost" != "null" ]; then break; fi
   echo -n '.'
   sleep 10
done
echo "dbhost=$dbhost"
