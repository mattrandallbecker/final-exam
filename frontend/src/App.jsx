import './App.css'
import '@fontsource/roboto/300.css';
import '@fontsource/roboto/400.css';
import '@fontsource/roboto/500.css';
import '@fontsource/roboto/700.css';
import { createClient } from '@connectrpc/connect';
import { createConnectTransport } from '@connectrpc/connect-web';
import { useEffect, useState } from 'react'
import { WeatherControlService } from '../codegen/weathercontrol_connect';
import Box from '@mui/material/Box';
import Button from '@mui/material/Button';
import Card from '@mui/material/Card';
import CardContent from '@mui/material/CardContent';
import ConfettiExplosion from 'react-confetti-explosion';
import Divider from '@mui/material/Divider';
import TextField from '@mui/material/TextField';
import Typography from '@mui/material/Typography';

const transport = createConnectTransport({
  baseUrl: import.meta.env.DEV ? 'http://localhost:8080' : '<CLOUD-RUN-BACKEND-URL>',
  useHttpGet: true,
});
export const API = createClient(WeatherControlService, transport);

function App() {
  const [weatherDisplay, setWeatherDisplay] = useState({ type: "Sunny", intensity: 1 })

  const [typeInput, setTypeInput] = useState("")
  const [intensityInput, setIntensityInput] = useState("")

  const [isExploding, setIsExploding] = useState(false);

  const getWeather = (confetti) => {
    API.getWeather({})
      .then(response => {
        setWeatherDisplay({ type: response.weatherType, intensity: response.intensity });
        if (confetti) {
          setIsExploding(!isExploding);
        }
        console.log(response);
      })
      .catch(console.log)
  }

  const setWeather = () => {
    API.setWeather({ weatherType: typeInput, intensity: Number(intensityInput) })
      .then(response => {
        console.log(response);
        setIsExploding(!isExploding);
      })
      .catch(console.log)
  }

  const resetExplosion = () => {
    setIsExploding(!isExploding);
  }

  useEffect(() => {
    getWeather(false)
  }, [])

  return (

    <Box sx={{ width: '100%', maxWidth: 500, backgroundColor: '#efefef', padding: '10px', margin: 'auto', borderRadius: '10px' }}>
      <Typography variant="h3" gutterBottom sx={{ textAlign: 'center' }}>
        Weather Control App
      </Typography>

      <Card variant="outlined">
        <CardContent>
          <Typography gutterBottom sx={{ color: 'text.secondary', fontSize: 14 }}>
            Current Weather In The World
          </Typography>
          <Typography variant="h4" component="div">
            {weatherDisplay.type}
          </Typography>
          <Typography sx={{ color: 'text.secondary', mb: 1.5 }}>Intensity: {weatherDisplay.intensity}</Typography>
          <Button variant="contained" size="small" onClick={getWeather}>Fetch Global Weather</Button>
        </CardContent>
      </Card>
      <Divider sx={{ margin: '10px 0' }} />
      {isExploding && <ConfettiExplosion force={0.8} duration={1000} particleCount={300} width={500} onComplete={resetExplosion} />}
      <Card variant="outlined">
        <CardContent>
          <Typography gutterBottom sx={{ color: 'text.secondary', fontSize: 14 }}>
            Update Worldly Weather
          </Typography>
          <TextField
            required
            name='type'
            value={typeInput}
            onInput={e => setTypeInput(e.target.value)}
            label="Weather Type"
            size="small"
            fullWidth
            sx={{ margin: '15px 0' }}
          />
          <TextField
            required
            name='intensity'
            value={intensityInput}
            onInput={e => setIntensityInput(e.target.value)}
            label="Intensity"
            size="small"
            fullWidth
            sx={{ margin: '0 0 15px 0' }}
          />
          <Button variant="contained" size="small" onClick={setWeather}>Set Global Weather</Button>
        </CardContent>
      </Card>
    </Box>

  )
}

export default App
