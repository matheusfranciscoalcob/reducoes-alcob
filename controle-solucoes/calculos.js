(function (root) {
  'use strict';
  const DEFAULT_CONFIG = {
    tankLengthM: 1.9, tankWidthM: 1.8, tankHeightCm: 110,
    boxCapacityLiters: 20000, boxHeightCm: 321,
    boxBottomDiameterM: 2.42, boxTopDiameterM: 3.2,
    minConcentrationPct: 2.5, maxConcentrationPct: 3
  };
  const DEFAULT_PICKLING_CONFIG = {
    tank1LengthM: 4, tank1WidthM: 3, tank1HeightCm: 300, tank1CapacityLiters: 24203,
    tank2LengthM: 3, tank2WidthM: 1.8, tank2HeightCm: 110,
    minConcentrationPct: 2.5, maxConcentrationPct: 3.5
  };
  function calculateTankVolume(heightCm, c = DEFAULT_CONFIG) {
    return c.tankLengthM * c.tankWidthM * (heightCm / 100) * 1000;
  }
  function calculateRectangularVolume(heightCm, lengthM, widthM) {
    return lengthM * widthM * (heightCm / 100) * 1000;
  }
  function calculateBoxVolume(heightCm, c = DEFAULT_CONFIG) {
    if (heightCm === 0) return 0;
    const H = c.boxHeightCm / 100, h = heightCm / 100;
    const r0 = c.boxBottomDiameterM / 2, r1 = c.boxTopDiameterM / 2;
    const rh = r0 + (r1 - r0) * (h / H);
    const partial = Math.PI * h / 3 * (r0 ** 2 + r0 * rh + rh ** 2);
    const full = Math.PI * H / 3 * (r0 ** 2 + r0 * r1 + r1 ** 2);
    return partial / full * c.boxCapacityLiters;
  }
  function calculateOilToAdd(volume, currentPct, targetPct) {
    if (currentPct >= targetPct) return 0;
    const ci = currentPct / 100, cf = targetPct / 100;
    return Math.max(0, volume * (cf - ci) / (1 - cf));
  }
  function calculateWaterToAdd(volume, currentPct, targetPct) {
    if (currentPct <= targetPct || targetPct <= 0) return 0;
    return Math.max(0, volume * (currentPct / targetPct - 1));
  }
  function inferObservedVolumeFromOil(oilAddedLiters, beforePct, afterPct) {
    const ci = beforePct / 100, cf = afterPct / 100;
    if (![oilAddedLiters, ci, cf].every(Number.isFinite) || oilAddedLiters <= 0 || cf <= ci || cf >= 1) return null;
    const volume = oilAddedLiters * (1 - cf) / (cf - ci);
    return Number.isFinite(volume) && volume > 0 ? volume : null;
  }
  function calibrationStats(samples) {
    const factors = samples.map(s => Number(s.factor)).filter(f => Number.isFinite(f) && f > 0).sort((a, b) => a - b);
    if (!factors.length) return { sampleCount: 0, rawFactor: 1, appliedFactor: 1, confidence: 'MODELO GEOMÉTRICO' };
    const middle = Math.floor(factors.length / 2);
    const median = factors.length % 2 ? factors[middle] : (factors[middle - 1] + factors[middle]) / 2;
    const priorWeight = 3;
    const applied = (priorWeight + factors.length * median) / (priorWeight + factors.length);
    const confidence = factors.length < 3 ? 'CALIBRAÇÃO INICIAL' : factors.length < 6 ? 'CONFIANÇA BAIXA' : factors.length < 11 ? 'CONFIANÇA MODERADA' : 'CONFIANÇA MAIOR';
    return { sampleCount: factors.length, rawFactor: median, appliedFactor: applied, confidence };
  }
  function classifyConcentration(currentPct, c = DEFAULT_CONFIG) {
    if (currentPct < c.minConcentrationPct) return 'ABAIXO DA FAIXA';
    if (currentPct > c.maxConcentrationPct) return 'ACIMA DA FAIXA';
    return 'DENTRO DA FAIXA';
  }
  function validateInputs(i, c = DEFAULT_CONFIG) {
    const e = [];
    if (!Object.values(i).every(Number.isFinite)) return ['Preencha todos os campos com números válidos.'];
    if (i.tankHeightCm < 0 || i.tankHeightCm > c.tankHeightCm) e.push(`A altura do tanque deve ficar entre 0 e ${c.tankHeightCm} cm.`);
    if (i.boxHeightCm < 0 || i.boxHeightCm > c.boxHeightCm) e.push(`A altura da caixa deve ficar entre 0 e ${c.boxHeightCm} cm.`);
    if (i.currentConcentrationPct < 0 || i.currentConcentrationPct > 100) e.push('A concentração atual deve ficar entre 0% e 100%.');
    if (i.targetConcentrationPct <= 0 || i.targetConcentrationPct >= 100) e.push('A concentração-alvo deve ficar entre 0% e 100%.');
    if (i.fixedAdditionalLiters < 0) e.push('O volume fixo adicional não pode ser negativo.');
    return e;
  }
  function calculateAll(i, c = DEFAULT_CONFIG, calibrationFactor = 1) {
    const tankVolumeLiters = calculateTankVolume(i.tankHeightCm, c);
    const boxVolumeLiters = calculateBoxVolume(i.boxHeightCm, c);
    const geometricVolumeLiters = tankVolumeLiters + boxVolumeLiters;
    const totalVolumeLiters = geometricVolumeLiters * calibrationFactor + i.fixedAdditionalLiters;
    const status = classifyConcentration(i.currentConcentrationPct, c);
    const oilToAddLiters = calculateOilToAdd(totalVolumeLiters, i.currentConcentrationPct, i.targetConcentrationPct);
    return {
      tankVolumeLiters, boxVolumeLiters, geometricVolumeLiters, totalVolumeLiters, calibrationFactor, status, oilToAddLiters,
      operationalOilLiters: Math.floor(oilToAddLiters / 5) * 5,
      waterTargetPct: c.maxConcentrationPct,
      waterToAddLiters: status === 'ACIMA DA FAIXA' ? calculateWaterToAdd(totalVolumeLiters, i.currentConcentrationPct, c.maxConcentrationPct) : 0
    };
  }
  function validatePicklingInputs(i, c = DEFAULT_PICKLING_CONFIG) {
    const e = [];
    if (!Object.values(i).every(Number.isFinite)) return ['Preencha todos os campos com números válidos.'];
    if (i.tank1HeightCm < 0 || i.tank1HeightCm > c.tank1HeightCm) e.push(`A altura da caixa 1 deve ficar entre 0 e ${c.tank1HeightCm} cm.`);
    if (i.tank2HeightCm < 0 || i.tank2HeightCm > c.tank2HeightCm) e.push(`A altura da caixa 2 deve ficar entre 0 e ${c.tank2HeightCm} cm.`);
    if (i.currentConcentrationPct < 0 || i.currentConcentrationPct > 100) e.push('A concentração atual deve ficar entre 0% e 100%.');
    if (i.targetConcentrationPct <= 0 || i.targetConcentrationPct >= 100) e.push('A concentração-alvo deve ficar entre 0% e 100%.');
    return e;
  }
  function calculatePicklingAll(i, c = DEFAULT_PICKLING_CONFIG, calibrationFactor = 1) {
    const tank1VolumeLiters = c.tank1CapacityLiters * i.tank1HeightCm / c.tank1HeightCm;
    const tank2VolumeLiters = calculateRectangularVolume(i.tank2HeightCm, c.tank2LengthM, c.tank2WidthM);
    const geometricVolumeLiters = tank1VolumeLiters + tank2VolumeLiters;
    const totalVolumeLiters = geometricVolumeLiters * calibrationFactor;
    const status = i.currentConcentrationPct < c.minConcentrationPct ? 'ABAIXO DA FAIXA' : i.currentConcentrationPct > c.maxConcentrationPct ? 'ACIMA DA FAIXA' : 'DENTRO DA FAIXA';
    const alcoholToAddLiters = status === 'ABAIXO DA FAIXA' ? calculateOilToAdd(totalVolumeLiters, i.currentConcentrationPct, i.targetConcentrationPct) : 0;
    return { tank1VolumeLiters, tank2VolumeLiters, geometricVolumeLiters, totalVolumeLiters, calibrationFactor, status, alcoholToAddLiters, operationalAlcoholLiters: Math.floor(alcoholToAddLiters / 5) * 5, waterTargetPct: c.maxConcentrationPct, waterToAddLiters: status === 'ACIMA DA FAIXA' ? calculateWaterToAdd(totalVolumeLiters, i.currentConcentrationPct, c.maxConcentrationPct) : 0 };
  }
  const api = { DEFAULT_CONFIG, DEFAULT_PICKLING_CONFIG, calculateTankVolume, calculateRectangularVolume, calculateBoxVolume, calculateOilToAdd, calculateWaterToAdd, inferObservedVolumeFromOil, calibrationStats, classifyConcentration, validateInputs, calculateAll, validatePicklingInputs, calculatePicklingAll };
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  root.EmulsionMath = api;
})(typeof window !== 'undefined' ? window : globalThis);
