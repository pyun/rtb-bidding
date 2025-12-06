#!/usr/bin/env python3
import json
import uuid
import random
import time
import requests
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime
import argparse
import string

# 默认request只有2666，通过page url调整包大小
EXTRA_INFO = ''.join(random.choices(string.ascii_letters + string.digits, k=400))
no_rtb_body = ''.join(random.choices(string.ascii_letters + string.digits, k=3048))

SERVER_URL_BID = "https://link-28nzwzeflwjrs6q3e9p7ezwle.297126936078.gateway.rtbfabric.us-east-1.amazonaws.com/bid"
SERVER_URL_NORTB = "https://link-28nzwzeflwjrs6q3e9p7ezwle.297126936078.gateway.rtbfabric.us-east-1.amazonaws.com/no_rtb"
SERVER_URL_NLB = "http://k8s-default-rtbbidse-f67e0ab541-e21ea20e6b018e25.elb.us-east-1.amazonaws.com:8080/bid"

SERVER_URL = SERVER_URL_NORTB

def generate_bid_request():
    os_list = ["iOS", "Android", "Web"]
    country_list = ["USA", "CA", "CN", "UA", "JP", "SIN"]
    
    request_id = str(uuid.uuid4())
    imp_id = str(uuid.uuid4())
    device_id = str(uuid.uuid4())
    user_id = str(uuid.uuid4())
    site_id = str(uuid.uuid4())
    publisher_id = str(uuid.uuid4())
    tag_id = str(uuid.uuid4())
    buyer_id = str(uuid.uuid4())
    os = random.choice(os_list)
    country = random.choice(country_list)
    
    return {
        "at": 1,
        "badv": ["facebook.com", "twitter.com", "google.com", "amazon.com", "youtube.com"],
        "bcat": ["12", "143", "34", "887", "122", "999", "1023", "13", "4", "565", "920", "224", "857", "1320"],
        "cur": ["USD"],
        "device": {
            "devicetype": 2,
            "ifa": device_id,
            "ip": f"{random.randint(1,255)}.{random.randint(1,255)}.{random.randint(1,255)}.{random.randint(1,255)}",
            "language": "en",
            "make": "desktop",
            "model": "browser",
            "os": os,
            "osv": "10",
            "ua": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/87.0.4280.88 Safari/537.36"
        },
        "ext": {"cattax": 2},
        "id": request_id,
        "imp": [{
            "banner": {
                "ext": {"qty": 2, "unit": 1},
                "h": 1092,
                "mimes": "text/html",
                "w": 1767
            },
            "bidfloor": round(random.uniform(1.0, 5.0), 2),
            "bidfloorcur": "USD",
            "exp": 4,
            "ext": {"ssai": 1},
            "id": imp_id,
            "tagid": tag_id
        }],
        "regs": {
            "coppa": 0,
            "ext": {"gdpr": 0, "sb568": 0}
        },
        "site": {
            "cat": ["1", "33", "544", "765", "1222", "1124", "789", "995", "133", "45", "76", "91"],
            "domain": "example.com",
            "page": "http://easy.example.com/easy?cu=13824;cre=mu;target=_blank" + EXTRA_INFO,
            "publisher": {
                "domain": "my.site.com",
                "id": publisher_id,
                "name": "site_name"
            },
            "ref": "http://tpc.googlesyndication.com/pagead/js/loader12.html?http://sdk.streamrail.com/vpaid/js/668/sam.js"
        },
        "source": {
            "ext": {"ts": str(int(time.time()))},
            "pchain": "1lmo0cdhb6woJTWl0Bouj5dXR5b",
            "tid": "1lmo0hJYZX5eH3BPmqHSVzYfSGa"
        },
        "tmax": 51,
        "user": {
            "buyeruid": buyer_id,
            "data": [{
                "id": "pub-demographics",
                "name": "data_name",
                "segment": [{
                    "id": "345qw245wfrtgwertrt56765wert",
                    "name": "segment_name",
                    "value": "segment_value"
                }]
            }],
            "gender": random.choice(["F", "M"]),
            "geo": {
                "city": "San Francisco",
                "country": country,
                "ext": {
                    "continent": "north america",
                    "dma": 650,
                    "state": "oklahoma"
                },
                "lat": 37.789,
                "lon": -122.394,
                "region": "CA",
                "type": 2,
                "zip": "94105"
            },
            "id": user_id,
            "yob": random.randint(1960, 2000)
        }
    }
def generate_no_rtb_request():
    return {
        "request": no_rtb_body
        }

def generate_request():
    # return generate_bid_request()
    return generate_no_rtb_request()

def send_request():
    try:
        bid_request = generate_request()
        response = requests.post(SERVER_URL, json=bid_request, timeout=2)
        print(f"[{datetime.now()}] Status: {response.status_code}, Response: {response.text}")
        return response.status_code
    except Exception as e:
        print(f"[{datetime.now()}] Error: {e}")
        return None

def run_client(concurrency, duration):
    start_time = time.time()
    total_requests = 0
    
    with ThreadPoolExecutor(max_workers=concurrency) as executor:
        while True:
            if duration > 0 and (time.time() - start_time) >= duration:
                break
            
            futures = [executor.submit(send_request) for _ in range(concurrency)]
            for future in futures:
                future.result()
                total_requests += 1
            
            if total_requests % 100 == 0:
                elapsed = time.time() - start_time
                qps = total_requests / elapsed if elapsed > 0 else 0
                print(f"[{datetime.now()}] Sent: {total_requests}, QPS: {qps:.2f}")
    
    elapsed = time.time() - start_time
    print(f"\nTotal: {total_requests} requests in {elapsed:.2f}s, Avg QPS: {total_requests/elapsed:.2f}")

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='RTB Client')
    parser.add_argument('-c', '--concurrency', type=int, default=10, help='Concurrent requests')
    parser.add_argument('-d', '--duration', type=int, default=0, help='Duration in seconds (0=infinite)')
    args = parser.parse_args()
    
    print(f"Starting RTB client: concurrency={args.concurrency}, duration={args.duration}")
    run_client(args.concurrency, args.duration)
