# Pod debug mạng một lần

```bash
k run tmp --rm -it --restart=Never --image=busybox:1.36 -- sh
# bên trong: nslookup <svc>.<ns> · wget -qO- -T 2 http://<svc>.<ns>:<port> · nc -zv <ip> <port>
```
