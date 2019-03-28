require 'flex_hash'

ah = FlexHash.new(/list|array/ => [], path: '')

ah[:k1, :k2, :k3] = 'yay'

ah

