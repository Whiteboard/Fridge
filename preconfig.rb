class Float
  def precision(pre)
    mult = 10 ** pre
    (self * mult).round.to_f / mult
  end
end