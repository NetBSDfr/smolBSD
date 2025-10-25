# smolBSD VM Manager <img src="static/smolBSD.png" alt="" width="10%">

## App Usage

## QuickStart

~~~
scripts/app-run.sh # just does Setup, Config & Run
firefox http://localhost:5000
~~~

## Setup

~~~
cd app/
python3 -m venv .
. bin/activate
pip install -r requirements.txt
~~~

## Running

~~~
cd app/
. bin/activate
flask run
~~~

## Configuration

~~~
- 1st, env vars have preference
- 2nd, app vars at .env
- 3rd, flask vars at .flaskenv
~~~

## Cleanup

~~~
rm -ri bin/ include/ lib/ lib64/ __pycache__/ pyvenv.cfg
~~~
