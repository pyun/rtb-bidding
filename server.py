#!/usr/bin/env python3
import json
import random
from flask import Flask, request, jsonify
from datetime import datetime
import string

app = Flask(__name__)

BID_RATE = 0.7
# 默认返回的bid response只有300，通过增加随机数来增加返回包
EXTRA_INFO = ''.join(random.choices(string.ascii_letters + string.digits, k=2748))

# no_rtb body
random_str = ''.join(random.choices(string.ascii_letters + string.digits, k=3048))

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "healthy"}), 200

@app.route('/bid', methods=['POST', 'GET'])
def bid():
    if request.method == 'GET':
        return jsonify({"status": "ok"}), 200
    
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
            "cur": "USD",
            "extra_info":EXTRA_INFO
        }
        print(f"[{datetime.now()}] Response: BID - Price: {response['seatbid'][0]['bid'][0]['price']}")
        return jsonify(response)
    else:
        print(f"[{datetime.now()}] Response: NO-BID")
        return jsonify({"id": bid_request['id'], "nbr": 2}), 204

@app.route('/no_rtb', methods=['POST', 'GET'])
def no_rtb():
    bid_request = request.get_json()
    print(f"[{datetime.now()}] Bid Request: {json.dumps(bid_request, indent=2)}")
    response = {
        "result": random_str,
    }
    
    return jsonify(response)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, threaded=True)
