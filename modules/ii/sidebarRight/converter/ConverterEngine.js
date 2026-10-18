/**
 * ConverterEngine.js
 * Unit conversion definitions and formula engine.
 */

.pragma library

const CATEGORIES = [
    {
        id: "length",
        name: "Length",
        icon: "straighten",
        units: [
            { id: "m", name: "Meters (m)", factor: 1 },
            { id: "km", name: "Kilometers (km)", factor: 1000 },
            { id: "cm", name: "Centimeters (cm)", factor: 0.01 },
            { id: "mm", name: "Millimeters (mm)", factor: 0.001 },
            { id: "in", name: "Inches (in)", factor: 0.0254 },
            { id: "ft", name: "Feet (ft)", factor: 0.3048 },
            { id: "yd", name: "Yards (yd)", factor: 0.9144 },
            { id: "mi", name: "Miles (mi)", factor: 1609.344 }
        ]
    },
    {
        id: "mass",
        name: "Mass",
        icon: "scale",
        units: [
            { id: "kg", name: "Kilograms (kg)", factor: 1 },
            { id: "g", name: "Grams (g)", factor: 0.001 },
            { id: "mg", name: "Milligrams (mg)", factor: 1e-6 },
            { id: "t", name: "Tonnes (t)", factor: 1000 },
            { id: "lb", name: "Pounds (lb)", factor: 0.45359237 },
            { id: "oz", name: "Ounces (oz)", factor: 0.028349523125 }
        ]
    },
    {
        id: "temp",
        name: "Temp",
        icon: "thermostat",
        units: [
            { id: "C", name: "Celsius (°C)" },
            { id: "F", name: "Fahrenheit (°F)" },
            { id: "K", name: "Kelvin (K)" }
        ]
    },
    {
        id: "time",
        name: "Time",
        icon: "timer",
        units: [
            { id: "s", name: "Seconds (s)", factor: 1 },
            { id: "min", name: "Minutes (min)", factor: 60 },
            { id: "h", name: "Hours (h)", factor: 3600 },
            { id: "d", name: "Days (d)", factor: 86400 },
            { id: "wk", name: "Weeks (wk)", factor: 604800 },
            { id: "ms", name: "Milliseconds (ms)", factor: 0.001 }
        ]
    },
    {
        id: "data",
        name: "Data",
        icon: "sd_card",
        units: [
            { id: "MB", name: "Megabytes (MB)", factor: 1e6 },
            { id: "GB", name: "Gigabytes (GB)", factor: 1e9 },
            { id: "TB", name: "Terabytes (TB)", factor: 1e12 },
            { id: "KB", name: "Kilobytes (KB)", factor: 1e3 },
            { id: "B", name: "Bytes (B)", factor: 1 },
            { id: "GiB", name: "Gibibytes (GiB)", factor: 1073741824 },
            { id: "MiB", name: "Mebibytes (MiB)", factor: 1048576 }
        ]
    },
    {
        id: "speed",
        name: "Speed",
        icon: "speed",
        units: [
            { id: "kmh", name: "km/h", factor: 1 / 3.6 },
            { id: "ms", name: "m/s", factor: 1 },
            { id: "mph", name: "Miles/h (mph)", factor: 0.44704 },
            { id: "knot", name: "Knots (kn)", factor: 0.514444 }
        ]
    }
];

function convert(categoryId, fromUnitId, toUnitId, value) {
    if (value === "" || value === undefined || value === null) return "";
    const num = parseFloat(value);
    if (isNaN(num)) return "";

    if (fromUnitId === toUnitId) {
        return cleanNumber(num);
    }

    if (categoryId === "temp") {
        // Temperature non-linear conversion
        let cVal = 0;
        if (fromUnitId === "C") cVal = num;
        else if (fromUnitId === "F") cVal = (num - 32) * 5 / 9;
        else if (fromUnitId === "K") cVal = num - 273.15;

        let res = 0;
        if (toUnitId === "C") res = cVal;
        else if (toUnitId === "F") res = cVal * 9 / 5 + 32;
        else if (toUnitId === "K") res = cVal + 273.15;

        return cleanNumber(res);
    }

    const cat = CATEGORIES.find(c => c.id === categoryId);
    if (!cat) return "";

    const fromUnit = cat.units.find(u => u.id === fromUnitId);
    const toUnit = cat.units.find(u => u.id === toUnitId);
    if (!fromUnit || !toUnit || !fromUnit.factor || !toUnit.factor) return "";

    // Base value in reference unit
    const baseVal = num * fromUnit.factor;
    const targetVal = baseVal / toUnit.factor;

    return cleanNumber(targetVal);
}

function cleanNumber(num) {
    if (isNaN(num) || !isFinite(num)) return "";
    // If absolute value is very small or very large, use exponential or precision
    if (Math.abs(num) < 1e-6 && num !== 0) {
        return num.toExponential(4);
    }
    const fixed = parseFloat(num.toPrecision(8));
    return String(fixed);
}
