#!/bin/bash

echo
curl -X POST -H 'Content-Type: application/json' --data '{"id":1,"jsonrpc":"2.0","method":"eth_chainId"}' http://127.0.0.1:8545

echo
curl -X POST -H 'Content-Type: application/json' --data '{"id":1,"jsonrpc":"2.0","method":"eth_getBalance","params": ["0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266","latest"]}' http://127.0.0.1:8545

echo
cast chain-id
cast balance 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266
