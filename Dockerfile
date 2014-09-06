FROM octohost/ruby-2.1.2

RUN apt-get update && apt-get install -y memcached

ADD . /srv/www

WORKDIR /srv/www

RUN bundle install

EXPOSE 5000

CMD memcached -u nobody -d && bundle exec ruby app.rb -p 5000
