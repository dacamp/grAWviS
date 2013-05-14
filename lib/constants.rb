KNOWN_NAMES = {
  '0.0.0.0/0'        => 'Internet',
  'xxxxxxxxxx'       => 'AWS Account',
  #  'x.x.x.x/0' => 'External',
  #  'y.y.y.y/0' => 'External',
}

KNOWN_STYLES =  lambda do
  hash = {
    'AWS Account' => { :color => 'lightblue' },
    'Internet'    => { :color => 'orange'},
    'amazon-elb'  => { :color => 'yellow'},
  }
  hash.default = { :color => 'red' }
  hash
end.call
