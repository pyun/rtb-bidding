#!/usr/bin/env python3
import json
import random
from flask import Flask, request, jsonify
from datetime import datetime

app = Flask(__name__)

BID_RATE = 0.7

@app.route('/bid', methods=['POST'])
def bid():
    bid_request = request.get_json()
    print(f"[{datetime.now()}] Bid Request: {json.dumps(bid_request, indent=2)}")
    
    if random.random() < BID_RATE:
        imp = bid_request['imp'][0]
        response = {
            "id": bid_request['id'],
            "seatbid": [{
                "bid": [{
                    "id": f"bid_{imp['id']}",
                    "impid": imp['id'],
                    "price": round(imp['bidfloor'] * random.uniform(1.1, 2.0), 2),
                    "adid": f"ad_{random.randint(1000, 9999)}",
                    "adm": "<html><body><h1>Ad Content</h1></body></html>",
                    "crid": f"creative_{random.randint(100, 999)}",
                    "w": imp['banner']['w'],
                    "h": imp['banner']['h']
                }]
            }],
            "cur": "USD"
        }
        print(f"[{datetime.now()}] Response: BID - Price: {response['seatbid'][0]['bid'][0]['price']}")
        return jsonify(response)
    else:
        print(f"[{datetime.now()}] Response: NO-BID")
        return jsonify({"id": bid_request['id'], "nbr": 2}), 204

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, threaded=True)
