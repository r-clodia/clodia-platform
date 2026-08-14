# Headers shared by every proxied location. Kept in one file so a header added
# for one upstream cannot silently be missing on another — which is how a
# request arrives with no Authorization and the failure looks like a permission
# problem instead of a routing one.
proxy_http_version 1.1;
proxy_set_header Host $host;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "";
