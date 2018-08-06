{-# LANGUAGE ScopedTypeVariables #-}

-- |
-- Module:      Math.NumberTheory.Beta
-- Copyright:   (c) 2018 Andrew Lelechenko
-- Licence:     MIT
-- Maintainer:  Andrew Lelechenko <andrew.lelechenko@gmail.com>
-- Stability:   Provisional
-- Portability: Non-portable (GHC extensions)
--
-- Dirichlet beta-function.

module Math.NumberTheory.Beta
  ( betas
  , betasEven
  , betasOdd
  , euler
  , eulerPolyAt1
  ) where

import Data.ExactPi                   (ExactPi (..), approximateValue)
import Data.List                      (zipWith4)
import Data.Ratio                     (Ratio, (%))

import Math.NumberTheory.Recurrencies (factorial, stirling2)
import Math.NumberTheory.Zeta         (skipOdds, suminf, zetasOdd)

-- | Infinite zero-based list of <https://en.wikipedia.org/wiki/Euler_number Euler numbers>.
-- The algorithm used was derived from <http://www.emis.ams.org/journals/JIS/VOL4/CHEN/AlgBE2.pdf Algorithms for Bernoulli numbers and Euler numbers>
-- by Kwang-Wu Chen, second formula of the Corollary in page 7.

-- >>> take 10 euler :: [Rational]
-- [1 % 1,0 % 1,(-1) % 1,0 % 1,5 % 1,0 % 1,(-61) % 1,0 % 1,1385 % 1,0 % 1]
euler :: forall a . Integral a => [Ratio a]
euler = map (f . tail) (tail stirling2)
  where
    f = sum . zipWith4 (\sgn fact a stir -> sgn * fact * stir * a) (cycle [1, -1])
                                                                   factorial
                                                                   as

    as :: Integral a => [Ratio a]
    as = zipWith3 (\sgn frac divByFour -> sgn * divByFour * frac) (cycle [1, 1, 1, 1, -1, -1, -1, -1])
                                                                  (dups (1 : iterate (/ 2) (1 % 2)))
                                                                  (cycle [1, 1, 1, 0])

    dups :: forall x . [x] -> [x]
    dups (n : ns) = n : n : dups ns
    dups l = l
{-# SPECIALIZE euler :: [Ratio Int]     #-}
{-# SPECIALIZE euler :: [Ratio Integer] #-}

-- | Infinite zero-based list of the @n@-th order Euler polynomials evaluated at @1@.
-- The algorithm used was derived from <http://www.emis.ams.org/journals/JIS/VOL4/CHEN/AlgBE2.pdf Algorithms for Bernoulli numbers and Euler numbers>
-- by Kwang-Wu Chen, third formula of the Corollary in page 7.
-- >>> take 10 eulerPolyAt1 :: [Rational]
-- [1 % 1,1 % 2,0 % 1,(-1) % 4,0 % 1,1 % 2,0 % 1,(-17) % 8,0 % 1,31 % 2]
eulerPolyAt1 :: forall a . Integral a => [Ratio a]
eulerPolyAt1 = map (f . tail) (tail stirling2)
  where
    f = sum . zipWith4 (\sgn fact twos stir -> (sgn * fact * stir) % twos)
                       (cycle [1, -1])
                       factorial
                       (iterate (2 *) 1)
{-# SPECIALIZE eulerPolyAt1 :: [Ratio Int]     #-}
{-# SPECIALIZE eulerPolyAt1 :: [Ratio Integer] #-}

-- | Infinite sequence of exact values of Dirichlet beta-function at odd arguments, starting with @β(1)@.
--
-- > > approximateValue (betasOdd !! 25) :: Double
-- > 0.9999999999999987
--
-- Using 'Data.Number.Fixed.Fixed':
--
-- > > approximateValue (betasOdd !! 25) :: Fixed Prec50
-- > 0.99999999999999999999999960726927497384196726751694z
--
betasOdd :: [ExactPi]
betasOdd = zipWith Exact [1, 3 ..] $ zipWith4 (\sgn denom eul twos -> sgn * (eul / (twos * denom)))
                                              (cycle [1, -1])
                                              (skipOdds factorial)
                                              (skipOdds euler)
                                              (iterate (4 *) 4)

-- | @betasOdd@, but with @forall a . Floating a => a@ instead of @ExactPi@s.
-- Used in @betasEven@.
betasOdd' :: Floating a => [a]
betasOdd' = map approximateValue betasOdd

-- | Infinite sequence of approximate values of the Dirichlet @β@ function at
-- positive even integer arguments, starting with @β(0)@.
betasEven :: forall a. (Floating a, Ord a) => a -> [a]
betasEven eps = (1 / 2) : bets
  where
    bets :: [a]
    bets = zipWith3 (\r1 r2 r3 -> (r1 + (negate r2) + r3)) rhs1 rhs2 rhs3

    evens = [0, 2 ..]

    odds = [1, 3 ..]

    skipEvens = skipOdds . tail

    -- [1!, 3!, 5!..]
    factorial1AsInteger :: [Integer]
    factorial1AsInteger = skipEvens factorial

    -- [1!, 3!, 5!..]
    factorial1 :: [a]
    factorial1 = map fromInteger factorial1AsInteger

    -- [1 / (2^1 * 1!), 1 / (2^3 * 3!), 1 /(2^5 * 5!), 1 / (2^7 * 7!) ..]
    fracs :: [Rational]
    fracs = zipWith (\pow fac -> 1 % (pow * fac)) factorial1AsInteger (iterate (4 *) 2)

    -- First term of the right hand side of (12).
    rhs1 = zipWith3 (\sgn piFrac lg -> sgn * (lg * approximateValue piFrac)) (cycle [1, -1])
                                                                           (zipWith Exact odds fracs)
                                                                           (repeat (log 2))

    -- [1 - (1 / (2^2)), 1 - (1 / (2^4)), 1 - (1 / (2^6)), ..]
    second :: [a]
    second = map (1 -) $ (iterate (/ 4) (1/4))

    -- [- (1 - (1 / (2^2))) * zeta(3), (1 - (1 / (2^4))) * zeta(5), - (1 - (1 / (2^6))) * zeta(7), ..]
    zets :: [a]
    zets = zipWith3 (\sgn twosFrac z -> sgn * twosFrac * z) (cycle [-1, 1])
                                                            second
                                                            (tail $ zetasOdd eps)

    -- [pi / (2^1 * 1!), pi^3 / (2^3 * 3!), pi^5 / (2^5 * 5!), ..]
    pisAndFacs :: [a]
    pisAndFacs = map approximateValue $ zipWith3 (\od pow fac -> Exact od (1 % (pow * fac)))
                                                 odds
                                                 (iterate (4 *) 2)
                                                 factorial1AsInteger

    -- [[], [pisAndFacs !! 0], [pisAndFacs !! 1, pisAndFacs !! 0], [pisAndFacs !! 2, pisAndFacs !! 1, pisAndFacs !! 0]...]
    pisAndFacs' :: [[a]]
    pisAndFacs' = scanl (flip (:)) [] pisAndFacs

    -- Second summand of RHS in (12) for k = [1 ..]
    rhs2 :: [a]
    rhs2 = zipWith (*) (cycle [-1, 1]) $ map (sum . zipWith (*) zets) pisAndFacs'

    -- [pi^3 / (2^4), pi^5 / (2^6), pi^7 / (2^8) ..]
    -- Second factor of third addend in RHS of (12).
    pis :: Floating a => [a]
    pis = map approximateValue $ zipWith Exact (tail odds) (map recip (iterate (4 *) 16))

    -- [[3!, 5!, 7! ..], [5!, 7! ..] ..]
    oddFacs :: [[a]]
    oddFacs = iterate tail (tail factorial1)

    -- [1, 4, 16 ..]
    fours :: [a]
    fours = iterate (4 *) 1

    -- [[3! * 2^0, 5! * 2^2, 7! * 2^4 ..], [5! * 2^0, 7! * 2^2, 9! * 2^4 ..] ..]
    infSumDenoms :: [[a]]
    infSumDenoms = map (zipWith (*) fours) oddFacs

    -- [pi^0, pi^2, pi^4, pi^6 ..]
    pis2 :: [a]
    pis2 = map approximateValue $ zipWith Exact evens (repeat 1)

    -- [pi^0 * E_1(1), - pi^2 * E_3(1), pi^4 * E_5(1) ..]
    infSumNum :: [a]
    infSumNum = zipWith3 (\sgn p eulerP -> sgn * p * eulerP) (cycle [1, -1])
                                                             pis2
                                                             (map fromRational . skipEvens $ eulerPolyAt1)

    -- [     [ pi^0 * E_1(1)  (-1) * pi^2 * E_3(1)   ]      [ (-1) * pi^2 * E_3(1)  pi^4 * E_5(1)    ]      [ pi^4 * E_5(1)  (-1) * pi^6 * E_7(1)    ]  ]
    -- | sum | -------------, -------------------- ..|, sum | --------------------, ------------- .. |, sum | -------------, -------------------- .. |..|
    -- [     [       3!                 5!           ]      [          5!                 7!         ]      [       7!                9!             ]  ]
    infSum :: [a]
    infSum = map (suminf eps . zipWith (/) infSumNum) infSumDenoms

    -- Third summand of the right hand side of (12).
    rhs3 :: [a]
    rhs3 = zipWith3 (\sgn p inf -> sgn * p * inf) (cycle [-1, 1])
                                                  pis
                                                  infSum

-- | Infinite sequence of approximate (up to given precision)
-- values of Dirichlet beta-function at integer arguments, starting with @β(0)@.
-- The algorithm used to compute @β@ for even arguments was derived from
-- <https://arxiv.org/pdf/0910.5004.pdf An Euler-type formula for β(2n) and closed-form expressions for a class of zeta series>
-- by F. M. S. Lima, formula (12).
--
-- > > take 5 (betas 1e-14) :: [Double]
-- > [0.5,0.7853981633974483,0.9159655941772191,0.9689461462593693,0.988944551741105]
betas :: (Floating a, Ord a) => a -> [a]
betas eps = e : o : scanl1 f (intertwine es os)
  where
    e : es = betasEven eps
    o : os = betasOdd'

    intertwine (x : xs) (y : ys) = x : y : intertwine xs ys
    intertwine xs ys = xs ++ ys

    -- Cap-and-floor to improve numerical stability:
    -- 0 < zeta(n + 1) - 1 < (zeta(n) - 1) / 2
    -- A similar method is used in @Math.NumberTheory.Zeta.zetas@.
    f x y = 1 `min` (y `max` (1 + (x - 1) / 2))